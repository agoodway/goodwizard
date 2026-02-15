# Markdown Search Reference Architecture

Reference architecture for a semantic markdown search OTP app using Bumblebee for embeddings and Vettore for in-memory vector search.

## Overall Architecture

| Module | Responsibility |
|---|---|
| `MdSearch.Files` | Discover and read markdown files from a root path |
| `MdSearch.Chunker` | Split files into chunks (by headings or tokens) |
| `MdSearch.Embedder` | Bumblebee `Nx.Serving` that turns text chunks into embeddings |
| `MdSearch.Index` | Wrapper around Vettore for add/search, returning file/chunk metadata |
| `MdSearch` | Public facade module (index repo, query repo) |

Markdown content lives on disk; only embeddings and light metadata live in Vettore.

## Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:vettore, "~> 0.1.7"},
    {:nx, "~> 0.9"},
    {:exla, "~> 0.9", only: [:dev, :prod]},
    {:bumblebee, "~> 0.5"},
    {:jason, "~> 1.4"}
  ]
end
```

Vettore is an in-memory vector DB implemented in Rust, exposed to Elixir via Rustler. Bumblebee uses Nx/EXLA to run HuggingFace models locally; Nomic and Jina text embedding models have working examples in Elixir.

```elixir
# config/config.exs
config :nx, default_backend: EXLA.Backend
```

Set `XLA_TARGET=cuda` for GPU acceleration.

## Bumblebee Embedding Serving

Pick a text embedding model — Nomic and Jina both behave like BERT, which Bumblebee supports via `TextEmbedding.text_embedding/3`.

```elixir
defmodule MdSearch.Embedder do
  use GenServer

  @model_repo "nomic-ai/nomic-embed-text-v1"
  # alternative: "jinaai/jina-embeddings-v2-base-en"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, model_info} =
      Bumblebee.load_model({:hf, @model_repo},
        architecture: :base,
        module: Bumblebee.Text.Bert
      )

    {:ok, tokenizer} =
      Bumblebee.load_tokenizer({:hf, @model_repo},
        module: Bumblebee.Text.BertTokenizer
      )

    serving =
      Bumblebee.Text.TextEmbedding.text_embedding(
        model_info,
        tokenizer,
        compile: [batch_size: 4, sequence_length: 512],
        defn_options: [compiler: EXLA],
        output_attribute: :hidden_state,
        output_pool: :mean_pooling
      )

    {:ok, serving}
  end

  def embed(texts) when is_binary(texts), do: embed([texts])

  def embed(texts) when is_list(texts) do
    GenServer.call(__MODULE__, {:embed, texts}, :infinity)
  end

  def handle_call({:embed, texts}, _from, serving) do
    %{embedding: embedding} = Nx.Serving.run(serving, texts)

    vectors =
      embedding
      |> Nx.to_batched_list()
      |> Enum.map(&Nx.to_flat_list/1)

    {:reply, vectors, serving}
  end
end
```

## Vettore Index Wrapper

Vettore exposes collections of vectors that you can insert and query by similarity.

```elixir
defmodule MdSearch.Index do
  use GenServer

  alias Vettore.Collection
  alias Vettore.Embedding

  @collection_name :md_chunks

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, collection} = Collection.new(@collection_name)
    {:ok, collection}
  end

  def add_chunk(%{
        id: id,
        embedding: embedding,
        file: file,
        rel_path: rel_path,
        span: span
      }) do
    GenServer.call(__MODULE__, {:add, id, embedding, file, rel_path, span})
  end

  def search(query_embedding, k \\ 5) do
    GenServer.call(__MODULE__, {:search, query_embedding, k})
  end

  def handle_call({:add, id, embedding, file, rel_path, span}, _from, collection) do
    metadata = %{
      file: file,
      rel_path: rel_path,
      span: span
    }

    embedding = %Embedding{
      value: id,
      vector: embedding,
      metadata: metadata
    }

    {:ok, collection} = Collection.insert(collection, embedding)
    {:reply, :ok, collection}
  end

  def handle_call({:search, query_embedding, k}, _from, collection) do
    {:ok, results} =
      Collection.search(collection, query_embedding,
        limit: k,
        metric: :cosine
      )

    {:reply, results, collection}
  end
end
```

Adjust the metric to match what Vettore supports (cosine, dot, etc.).

## Markdown Discovery, Parsing, and Chunking

File discovery:

```elixir
defmodule MdSearch.Files do
  def list_md_files(root) do
    Path.wildcard(Path.join(root, "**/*.md"))
  end

  def read_file(path) do
    File.read!(path)
  end

  def relative_path(root, full) do
    Path.relative_to(full, root)
  end
end
```

Heading-based chunking with max-char fallback:

```elixir
defmodule MdSearch.Chunker do
  @heading ~r/^\s*#+\s+/

  def chunk(content, opts \\ []) do
    max_chars = Keyword.get(opts, :max_chars, 1000)

    content
    |> String.split(~r/\R{2,}/, trim: true)
    |> Enum.reduce({[], []}, fn block, {chunks, current} ->
      if Regex.match?(@heading, block) and current != [] do
        {[Enum.join(Enum.reverse(current), "\n\n") | chunks], [block]}
      else
        {chunks, [block | current]}
      end
    end)
    |> finalize()
    |> Enum.flat_map(&split_large(&1, max_chars))
    |> Enum.with_index()
    |> Enum.map(fn {text, i} ->
      %{index: i, text: text}
    end)
  end

  defp finalize({chunks, current}) do
    chunks =
      case current do
        [] -> chunks
        _ -> [Enum.join(Enum.reverse(current), "\n\n") | chunks]
      end

    Enum.reverse(chunks)
  end

  defp split_large(text, max_chars) when byte_size(text) <= max_chars, do: [text]

  defp split_large(text, max_chars) do
    String.codepoints(text)
    |> Enum.chunk_every(max_chars)
    |> Enum.map(&Enum.join/1)
  end
end
```

Swap for token-based chunking later if tighter control is needed.

## Indexing a Repository

High-level batch index function:

```elixir
defmodule MdSearch do
  alias MdSearch.{Files, Chunker, Embedder, Index}

  def index_repo(root, opts \\ []) do
    files = Files.list_md_files(root)
    batch_size = Keyword.get(opts, :batch_size, 8)

    files
    |> Enum.with_index()
    |> Enum.each(fn {path, file_i} ->
      rel = Files.relative_path(root, path)
      content = Files.read_file(path)

      chunks = Chunker.chunk(content, max_chars: 1500)

      chunks
      |> Enum.chunk_every(batch_size)
      |> Enum.each(fn batch ->
        texts = Enum.map(batch, & &1.text)
        embeddings = Embedder.embed(texts)

        Enum.zip(batch, embeddings)
        |> Enum.each(fn {%{index: chunk_i, text: _text}, embedding} ->
          id = "#{rel}:#{chunk_i}"

          Index.add_chunk(%{
            id: id,
            embedding: embedding,
            file: path,
            rel_path: rel,
            span: %{chunk_index: chunk_i}
          })
        end)
      end)

      IO.puts("Indexed #{rel} (#{file_i + 1}/#{length(files)})")
    end)
  end

  def search(query, k \\ 5) do
    [embedding] = Embedder.embed(query)
    Index.search(embedding, k)
  end
end
```

Markdown stays on disk while embeddings live in the in-memory Vettore collection.

## Supervision Tree

```elixir
children = [
  MdSearch.Embedder,
  MdSearch.Index
]
```

Ensures the embedding serving and vector index are long-lived processes ready for requests.

## Query Flow

Query API that rehydrates markdown content from disk:

```elixir
defmodule MdSearch.Query do
  alias MdSearch.{Embedder, Index}

  def search(query, k \\ 5) do
    [q_embedding] = Embedder.embed(query)
    {:ok, matches} = Index.search(q_embedding, k)

    Enum.map(matches, fn result ->
      %{value: id, metadata: meta, score: score} = result

      {:ok, content} = File.read(meta.file)

      %{
        id: id,
        score: score,
        file: meta.file,
        rel_path: meta.rel_path,
        span: meta.span,
        content: content
      }
    end)
  end
end
```

Refine `span` to include byte offsets or heading IDs to return only the relevant snippet instead of the whole file.

## Performance and Scaling Notes

- For tens to hundreds of thousands of chunks, an in-memory Vettore collection is reasonable if you only store embeddings and small metadata.
- Avoid putting long markdown strings into Vettore metadata — keep those on disk or in a DB.
- Batch embeddings (8-32 texts per call) to make Bumblebee/EXLA efficient.
- For persistence, periodically serialize embeddings and metadata to disk (ETS dump, JSON/NDJSON, or a DB) and rebuild the Vettore collection on boot.
