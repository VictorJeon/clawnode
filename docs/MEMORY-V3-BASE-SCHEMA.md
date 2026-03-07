# Memory V3 Base Schema

> 목적: `003_memories.sql` 이전에 이미 존재해야 하는 base schema를 고정한다.
> 출처: 현재 dev DB `memory_v2`의 live schema (`postgresql@16`) 확인 결과.

---

## 1. 왜 필요한가

현재 `services/memory-v2/migrations`에는 아래만 있다.

- `003_memories.sql`
- `004_memory_v3_phase2.sql`
- `005_bilingual_facts.sql`
- `006_eviction.sql`

하지만 `003_memories.sql`은 이미 아래가 존재한다고 가정한다.

- `memory_documents`
- `memory_chunks`
- `vector` extension

즉 setup V2는 `003`부터 바로 실행하면 안 된다.

---

## 2. 검증된 기준 환경

- PostgreSQL: `Homebrew postgresql@16`
- DB: `memory_v2`
- `psql`: `/opt/homebrew/opt/postgresql@16/bin/psql`
- `pg_config --sharedir`: `/opt/homebrew/opt/postgresql@16/share/postgresql@16`
- `pg_config --pkglibdir`: `/opt/homebrew/opt/postgresql@16/lib/postgresql`

추가 확인:
- 설치된 extension: `vector 0.8.0`
- `gen_random_uuid()`는 `pg_catalog`에 존재

즉 최소 bring-up 기준으로는:
- `vector` extension은 필요
- `pgcrypto` extension은 현재 확인 범위에서는 필수 아님

---

## 3. Base Schema 계약

### 3.1 `memory_documents`

컬럼:
- `id uuid primary key default gen_random_uuid()`
- `namespace text not null`
- `source_type text not null`
- `source_path text`
- `source_hash text not null`
- `title text`
- `tags text[] default '{}'::text[]`
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

인덱스 / 제약:
- primary key on `id`
- unique `(namespace, source_path, source_hash)`
- btree index on `namespace`

### 3.2 `memory_chunks`

컬럼:
- `id uuid primary key default gen_random_uuid()`
- `document_id uuid not null references memory_documents(id) on delete cascade`
- `chunk_index integer not null`
- `content text not null`
- `token_count integer not null`
- `embedding vector(1024) not null`
- `content_tsv tsvector generated always as (to_tsvector('simple', content)) stored`
- `created_at timestamptz default now()`
- `status text not null default 'active'`
- `status_confidence double precision not null default 0.5`
- `decided_at timestamptz`
- `source_date date`

인덱스 / 제약:
- primary key on `id`
- unique `(document_id, chunk_index)`
- btree index on `document_id`
- btree index on `source_date`
- btree index on `status`
- gin index on `content_tsv`
- hnsw index on `embedding vector_cosine_ops`

주의:
- live DB에는 embedding HNSW index가 2개 있다
  - `idx_chunks_embedding`
  - `memory_chunks_embedding_idx`
- setup V2에서는 중복 인덱스를 그대로 복제하지 말고, 어떤 인덱스 하나를 표준으로 둘지 정리해야 한다

---

## 4. setup V2에 필요한 결론

1. `003_memories.sql` 이전에 base schema migration이 새로 필요하다
2. 그 migration은 최소한 `vector` extension + `memory_documents` + `memory_chunks`를 포함해야 한다
3. Homebrew 기준 첫 구현은 `postgresql@16`을 기준으로 잡는 것이 안전하다
4. `postgresql@17` 전환은 `pgvector` extension 설치/로드 검증 뒤에 별도 진행한다

현재 installer 초안 파일:
- [001_base_schema.sql](/Users/nova/projects/clawnode/installer/templates/memory-v3/001_base_schema.sql)

---

## 5. 비범위

아래는 현재 base schema 문서의 범위 밖이다.

- `memories`, `memory_relations`, `pending_atomize`, `project_snapshots`
- `fact_ko_backfill_meta`
- `llm_atomize_runs`

설명:
- 앞의 네 개는 `003~006` migration 범위
- 뒤의 두 개는 worker/backfill runtime이 `CREATE TABLE IF NOT EXISTS`로 관리하는 보조 테이블이다
