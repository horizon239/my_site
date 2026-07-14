-- 테스트용 페이지(mockup_test) PDF 업로드 기능 설정
-- Supabase 대시보드 > SQL Editor 에서 이 파일 전체를 실행하세요.
--
-- 구조:
--   mockup_pages 테이블: 버전(v1/v2/v3)별로 변환된 이미지(JPEG data URI 배열)를 저장
--   업로드는 반드시 upload_mockup_page() 함수를 통해서만 가능하며,
--   이 함수 내부에서 비밀번호(8316)를 서버 측에서 직접 검증한다.
--   anon 키로는 테이블에 직접 INSERT/UPDATE 할 수 없다 (정책을 부여하지 않음) —
--   RLS가 켜져 있고 쓰기 정책이 없으므로 기본적으로 모든 쓰기가 차단된다.

create table if not exists mockup_pages (
  version text primary key check (version in ('v1', 'v2', 'v3')),
  images jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table mockup_pages enable row level security;

-- 읽기는 누구나 가능 (뷰어 페이지가 이미지를 불러와야 하므로)
drop policy if exists "mockup_pages_public_read" on mockup_pages;
create policy "mockup_pages_public_read"
  on mockup_pages for select
  using (true);

grant select on mockup_pages to anon, authenticated;

-- 업로드 함수: 비밀번호를 서버에서 검증 후에만 upsert 수행
create or replace function upload_mockup_page(p_version text, p_password text, p_images jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_password is distinct from '8316' then
    raise exception 'invalid password';
  end if;

  if p_version not in ('v1', 'v2', 'v3') then
    raise exception 'invalid version';
  end if;

  insert into mockup_pages (version, images, updated_at)
  values (p_version, p_images, now())
  on conflict (version) do update
    set images = excluded.images,
        updated_at = now();
end;
$$;

grant execute on function upload_mockup_page(text, text, jsonb) to anon, authenticated;
