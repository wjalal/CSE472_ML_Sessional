--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: meme_typename; Type: TYPE; Schema: public; Owner: doadmin
--

CREATE TYPE public.meme_typename AS ENUM (
    'waiting',
    'failure',
    'success'
);


ALTER TYPE public.meme_typename OWNER TO doadmin;

--
-- Name: user_typename; Type: TYPE; Schema: public; Owner: doadmin
--

CREATE TYPE public.user_typename AS ENUM (
    'staff',
    'alum',
    'student'
);


ALTER TYPE public.user_typename OWNER TO doadmin;

--
-- Name: add_new_meme(text, text, text, boolean); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.add_new_meme(given_img_url text, given_sound_url text, given_content text, given_is_audio boolean) RETURNS record
    LANGUAGE plpgsql
    AS $$declare 
	_result record := null;
begin
	
	insert into public.memes
		(
			img_url,
			sound_url,
			"content",
			is_audio 
		)
		values 
		(
			given_img_url, 
			given_sound_url,
			given_content,
			given_is_audio
		) returning memes.id, memes.created_at, memes.img_url, memes.sound_url, memes.is_audio, memes.meme_type into _result;
	return _result;
end;$$;


ALTER FUNCTION public.add_new_meme(given_img_url text, given_sound_url text, given_content text, given_is_audio boolean) OWNER TO doadmin;

--
-- Name: add_new_puzzle(text, text, bigint, text, text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.add_new_puzzle(given_img_url text, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) RETURNS record
    LANGUAGE plpgsql
    AS $$declare 
	_result record:=null;
begin
	
	insert into public.puzzles
		(
			img_url,
			ans,
			puzzle_level,
			title,
			info,
			info_link
		)
		values 
		(
			given_img_url, 
			given_hashed_ans,
			given_puzzle_level ,
			given_title,
			given_info,
			given_info_link
		) returning puzzles.id, puzzles.created_at ,puzzles.img_url , puzzles.ans, puzzles.puzzle_level, puzzles.title , puzzles.info , puzzles.info_link   into _result;
	return _result;
end;$$;


ALTER FUNCTION public.add_new_puzzle(given_img_url text, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) OWNER TO doadmin;

--
-- Name: add_puzzle_attempt(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.add_puzzle_attempt(given_user_id uuid, given_puzzle_id uuid, given_ans text) RETURNS TABLE(f_is_correct boolean, f_next_puzzle_id uuid, f_next_puzzle_img_url text, f_next_puzzle_level bigint, f_meme_id uuid, f_img_url text, f_sound_url text, f_content text, f_is_audio boolean, f_rank bigint)
    LANGUAGE plpgsql
    AS $$declare 
	_is_correct boolean:=false;
	_correct_ans text:=null;
	_level bigint:=0;
	_new_level bigint=-1;
	_id integer:=0;
	_high integer:=0;
	_r record:=null;
	_rank bigint:=-1;
	_student_id text:=null;
begin
	select student_id into _student_id from public.users where id = given_user_id;
	select ans into _correct_ans from public.puzzles where id = given_puzzle_id;
	select puzzle_level into _level from public.puzzles where id = given_puzzle_id;

	if _correct_ans = given_ans 
	then 
		_is_correct := true;

		update public.users set curr_level = curr_level + 1 where id = given_user_id;
	end if;

	WITH sorted_table AS (
	    	SELECT *,
        	   -- Assuming 'id' is the primary key used for sorting
	           -- Replace 'id' with the actual column used for sorting
           	ROW_NUMBER() OVER (ORDER BY p.puzzle_level) AS row_number
    		FROM public.puzzles p 
		)
	SELECT next_row.puzzle_level into _new_level
	FROM (
	    SELECT *
	    FROM sorted_table
	    WHERE sorted_table.puzzle_level = _level -- Specify your condition here
	) current_row
	LEFT JOIN (
	    SELECT *
	    FROM sorted_table
	) next_row ON current_row.row_number + 1 = next_row.row_number;

	insert into public.puzzle_attempts
		(
			user_id,
			puzzle_id,
			is_correct,
			submitted_ans,
			puzzle_level 
		)
		values 
		(
			given_user_id, 
			given_puzzle_id, 
			_is_correct,
			given_ans,
			_level
		) ;
--	raise notice '%', _new_level;
	
--	select into _high count(*) from public.memes;
--	select into _id floor(random() * (_high) + 1)::integer;
--	select * from public.memes where memes.id = _id into _r;

	with leaderboard as 
	(
		select *, 
			row_number() over (order by p.f_curr_level desc, p.f_last_submission_time asc) as row_number 
		from public.get_leaderboard() p
	)
	select leaderboard.row_number into _rank
	from leaderboard
	where leaderboard.f_student_id = _student_id;
	
	if _is_correct <> true then 
		return query
		with meme_src as (SELECT * FROM public.memes m where m.meme_type = 'failure' ORDER BY RANDOM() LIMIT 1 )
		select _is_correct, null::uuid, null::text, null::bigint, m.id as meme_id, m.img_url , m.sound_url, m."content", m.is_audio, _rank as f_rank from meme_src m; 
	else 
		
		if _new_level <> -1 and _new_level < 40 then 
			
			return query 
			with meme_src as (SELECT * FROM public.memes m where m.meme_type = 'success' ORDER BY RANDOM() LIMIT 1 )
			select _is_correct, p.id, p.img_url , _new_level, m.id as meme_id,  m.img_url, m.sound_url,m."content", m.is_audio , _rank as f_rank from public.puzzles p, meme_src m where p.puzzle_level  = _new_level ;
		else 
			
			return query 
			with meme_src as (SELECT * FROM public.memes m where m.meme_type = 'success' ORDER BY RANDOM() LIMIT 1 )
			select _is_correct, null::uuid, null::text, null::bigint, m.id as meme_id, m.img_url , m.sound_url, m."content", m.is_audio, _rank as f_rank from meme_src m;
		end if;
		
	end if;
	
end;$$;


ALTER FUNCTION public.add_puzzle_attempt(given_user_id uuid, given_puzzle_id uuid, given_ans text) OWNER TO doadmin;

--
-- Name: add_user(text, text, bigint, text, text, public.user_typename); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.add_user(given_username text, given_student_id text, given_batch bigint, given_pwd_hash text, given_email text, given_user_type public.user_typename) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
declare
	_result uuid:=null;
begin
	if  
		given_username  in (select u.username from public.users u) 
		or
		given_student_id  in (select u.student_id from public.users u)
	then
		return _result;
	end if;	


	insert into public.users 
	(username, student_id, batch, password_hash, email, user_type)
	values 
	(given_username, given_student_id, given_batch, given_pwd_hash, given_email, given_user_type)
	returning id into _result;
	return _result;
	
end;
$$;


ALTER FUNCTION public.add_user(given_username text, given_student_id text, given_batch bigint, given_pwd_hash text, given_email text, given_user_type public.user_typename) OWNER TO doadmin;

--
-- Name: can_access_admin(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.can_access_admin(given_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare 
	_type user_typename:=null;
begin
	select into _type u.user_type from public.users u where u.id = given_user_id;
	if  
		_type = 'staff'
	then
		return true;
	else 
		return false;
	end if;
	
end;
$$;


ALTER FUNCTION public.can_access_admin(given_user_id uuid) OWNER TO doadmin;

--
-- Name: can_login_user(text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.can_login_user(given_username text, given_pwd_hash text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
declare
	_pwd_hash text:=null;
	_result uuid:=null;
begin
	if  
		given_username not in (select u.username from public.users u) 
		or
		given_pwd_hash not in (select u.password_hash from public.users u)
	then
		return _result;
	else 
		select into _pwd_hash u.password_hash from public.users u where u.username = given_username;
		if _pwd_hash <> given_pwd_hash
		then 
			return _result;
		else 
			select u.id into _result from public.users u where u.username = given_username;
			return _result;
		end if;
	end if;
	
end;
$$;


ALTER FUNCTION public.can_login_user(given_username text, given_pwd_hash text) OWNER TO doadmin;

--
-- Name: can_signup_user(text, text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.can_signup_user(given_username text, given_student_id text, given_email text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

begin
	if  
		given_username not in (select u.username from public.users u) 
		and
		given_student_id not in (select u.student_id from public.users u)
	then
		return true;
	else 
		return false;
	end if;
	
end;
$$;


ALTER FUNCTION public.can_signup_user(given_username text, given_student_id text, given_email text) OWNER TO doadmin;

--
-- Name: delete_meme(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.delete_meme(given_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare 
	_result integer:=0;
begin
	
	delete  from public.memes m where m.id = given_id;
	get diagnostics _result = row_count;
	return _result;
end;
$$;


ALTER FUNCTION public.delete_meme(given_id uuid) OWNER TO doadmin;

--
-- Name: delete_puzzle(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.delete_puzzle(given_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare 
	_result integer:=0;
begin
	
	delete  from public.puzzles p where p.id = given_id;
	get diagnostics _result = row_count;
	return _result;
end;
$$;


ALTER FUNCTION public.delete_puzzle(given_id uuid) OWNER TO doadmin;

--
-- Name: delete_user(text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.delete_user(given_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare 
	_result integer:=0;
	_c integer:= 0;
begin
	select count(u.id) into _c from public.users u where u.username = given_name;
	if (_c = 0) then return 0; end if;
	delete  from public.users u where u.username = given_name;
	get diagnostics _result = row_count;
	return _result;
end;
$$;


ALTER FUNCTION public.delete_user(given_name text) OWNER TO doadmin;

--
-- Name: get_all_memes(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_all_memes() RETURNS TABLE(f_created_at timestamp with time zone, f_img_url text, f_sound_url text, f_content text, f_is_audio boolean, f_id uuid, f_meme_type public.meme_typename)
    LANGUAGE plpgsql
    AS $$
begin
	return query 
	select * from public.memes order by created_at desc;
end;
$$;


ALTER FUNCTION public.get_all_memes() OWNER TO doadmin;

--
-- Name: get_all_puzzles(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_all_puzzles() RETURNS TABLE(f_id uuid, f_created_at timestamp with time zone, f_img_url text, f_ans text, f_puzzle_level bigint, f_title text, f_info text, f_info_link text)
    LANGUAGE plpgsql
    AS $$begin
	return query 
	select p.id , p.created_at ,p.img_url , p.ans ,p.puzzle_level, p.title ,p.info ,p.info_link  from public.puzzles p order by puzzle_level asc;
end;$$;


ALTER FUNCTION public.get_all_puzzles() OWNER TO doadmin;

--
-- Name: get_arena_metadata(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_arena_metadata() RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_r record:=null;
begin
	select 
		(select count(*) from public.users u) as total_users,
		(select count(*) from public.users u where u.user_type = 'staff') as total_staff,
		(select count(*) from public.users u where u.user_type = 'alum') as total_alums,
		(select count(*) from public.users u where u.user_type = 'student') as total_students,
		(select count(*) from public.puzzle_attempts) as total_submissions,
		(select count(*) from public.puzzles) as total_puzzles,
		(select max(u.curr_level) from public.users u) as max_user_level,
		(select count(*) from public.memes) as total_memes
	into _r;
	return _r;
	
end;
$$;


ALTER FUNCTION public.get_arena_metadata() OWNER TO doadmin;

--
-- Name: get_leaderboard(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_leaderboard() RETURNS TABLE(f_username text, f_curr_level bigint, f_student_id text, f_last_submission_time timestamp with time zone, f_shomobay_score double precision)
    LANGUAGE plpgsql
    AS $$

begin
	return query
		select
			u.username, 
			(
			select count(*) 
			from public.users u2 join public.puzzle_attempts pa2 on u2.id = pa2.user_id 
			where u.student_id = u2.student_id and pa2.is_correct =  true 
			) as f_curr_level, 
			u.student_id, 
			(	
			select max(pa2.submitted_at)
			from public.users u2 join public.puzzle_attempts pa2 on u2.id = pa2.user_id 
			where u.student_id = u2.student_id 
			) as f_last_submission_time,
			u.shomobay_score as f_shomobay_score
		from public.users u join public.puzzle_attempts pa on u.id = pa.user_id 
		where u.user_type <> 'staff'
		group by u.student_id, u.username, u.shomobay_score
		order by f_curr_level desc, f_last_submission_time asc;
end;
$$;


ALTER FUNCTION public.get_leaderboard() OWNER TO doadmin;

--
-- Name: get_leaderboard_chunk(bigint); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_leaderboard_chunk(given_offset bigint) RETURNS TABLE(f_username text, f_curr_level bigint, f_student_id text, f_last_submission_time timestamp with time zone, f_shomobay_score double precision, f_rank bigint)
    LANGUAGE plpgsql
    AS $$
begin
	

	return query
		with leaderboard as 
	(
		select *, 
			row_number() over (order by p.f_curr_level desc, p.f_last_submission_time asc) as row_number 
		from public.get_leaderboard() p
	)
	select *
	from leaderboard
		limit 100 offset given_offset * 100;
end;
$$;


ALTER FUNCTION public.get_leaderboard_chunk(given_offset bigint) OWNER TO doadmin;

--
-- Name: get_leaderboard_details(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_leaderboard_details() RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_r record:=null;
begin
	select 
		(select count(*) from public.get_leaderboard()) as leaderboard_length
	into _r;
	return _r;
	
end;
$$;


ALTER FUNCTION public.get_leaderboard_details() OWNER TO doadmin;

--
-- Name: get_leaderboard_for_admins(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_leaderboard_for_admins() RETURNS TABLE(f_username text, f_curr_level bigint, f_user_type public.user_typename, f_student_id text, f_email text, f_last_submission_time timestamp with time zone, f_total_submissions bigint, f_shomobay_score double precision)
    LANGUAGE plpgsql
    AS $$

begin
	return query
		select
			u.username, 
			(
			select count(*) 
			from public.users u2 join public.puzzle_attempts pa2 on u2.id = pa2.user_id 
			where u.student_id = u2.student_id and pa2.is_correct =  true
			) as f_curr_level, 
			(
			select u3.user_type 
			from public.users u3 
			where u3.student_id = u.student_id
			) as f_user_type,
			u.student_id, 
			u.email,
			(
			select max(pa2.submitted_at)
			from public.users u2 join public.puzzle_attempts pa2 on u2.id = pa2.user_id 
			where u.student_id = u2.student_id 
			) as f_last_submission_time,
			(
			select count(*) 
			from public.users u2 join public.puzzle_attempts pa2 on u2.id = pa2.user_id 
			where u.student_id = u2.student_id
			) as f_total_submissions,
			(
			select u3.shomobay_score  
			from public.users u3 
			where u3.student_id = u.student_id
			) as f_shomobay_score
		from public.users u join public.puzzle_attempts pa on u.id = pa.user_id 
		group by u.student_id, u.username, u.email 
		order by f_curr_level desc, f_last_submission_time asc;
end;
$$;


ALTER FUNCTION public.get_leaderboard_for_admins() OWNER TO doadmin;

--
-- Name: get_random_meme(); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_random_meme() RETURNS record
    LANGUAGE plpgsql
    AS $$declare 
	_index integer:=0;
	_high integer:=0;
	_r record:=null;
begin
	select into _high count(*) from public.memes;
	_index := floor(random() * _high)::integer;
	select * into _r from public.memes offset _index limit 1;
	return _r;
end;$$;


ALTER FUNCTION public.get_random_meme() OWNER TO doadmin;

--
-- Name: get_user_all_submissions(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_user_all_submissions(given_user_id uuid) RETURNS TABLE(f_puzzle_id bigint, f_submitted_ans text, f_is_correct boolean, f_submitted_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$

begin
	return query
	select pa.puzzle_id, pa.submitted_ans, pa.is_correct, pa.submitted_at from public.puzzle_attempts pa where pa.user_id = given_user_id
	order by pa.submitted_at desc;
end;
$$;


ALTER FUNCTION public.get_user_all_submissions(given_user_id uuid) OWNER TO doadmin;

--
-- Name: get_user_correct_submissions(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_user_correct_submissions(given_user_id uuid) RETURNS TABLE(f_puzzle_id bigint, f_submitted_ans text, f_is_correct boolean, f_submitted_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$

begin
	return query
	select pa.puzzle_id, pa.submitted_ans, pa.is_correct, pa.submitted_at from public.puzzle_attempts pa 
	where pa.user_id = given_user_id and pa.is_correct = true
	order by pa.submitted_at desc;
end;
$$;


ALTER FUNCTION public.get_user_correct_submissions(given_user_id uuid) OWNER TO doadmin;

--
-- Name: get_user_details(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_user_details(given_user_id uuid) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_r record:=null;
	_student_id text:=null;
	_position integer:=0;
	_level bigint:=0;
begin
	
	select u.student_id into _student_id from public.users u where u.id = given_user_id;

	select u.curr_level into _level from public.users u where u.id = given_user_id;
	_level:= _level+1;

	select 
		u.id, u.username, u.student_id, u.curr_level, u.email, 
		(
		select num 
		from (
			select row_number() over() as num, f_student_id from get_leaderboard()
		) as _t2 
		where _t2.f_student_id = _student_id
		) as user_rank,
		(
		select p.id from public.puzzles p where p.puzzle_level = _level
		) as next_puzzle_id,
		(
		select p.img_url from public.puzzles p where p.puzzle_level = _level
		) as next_puzzle_url,
		( 
		select p.puzzle_level from public.puzzles p where p.puzzle_level = _level
		) as next_puzzle_level,
		u.is_banned as f_is_banned
	from public.users u
	where u.id = given_user_id into _r;
	return _r;
end;
$$;


ALTER FUNCTION public.get_user_details(given_user_id uuid) OWNER TO doadmin;

--
-- Name: get_user_next_puzzle(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_user_next_puzzle(given_user_id uuid) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_level bigint:=0;
	_r record:=null;
begin
	select u.curr_level into _level from public.users u where u.id = given_user_id;
	_level:= _level+1;
	select p.id, p.img_url, p.puzzle_level from public.puzzles p where p.puzzle_level = _level into _r;
	return _r;
end;
$$;


ALTER FUNCTION public.get_user_next_puzzle(given_user_id uuid) OWNER TO doadmin;

--
-- Name: get_uuid_hash(text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.get_uuid_hash(given_username text) RETURNS TABLE(id uuid, hash text, is_banned boolean)
    LANGUAGE plpgsql
    AS $$
  begin
    if  given_username not in (select u.username from public.users u)
    then
      return query select null::uuid, '', null::boolean;
    else 
      return query select u.id, u.password_hash, u.is_banned from public.users u where u.username = given_username;
    end if;
  end;
$$;


ALTER FUNCTION public.get_uuid_hash(given_username text) OWNER TO doadmin;

--
-- Name: is_user_banned(uuid); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.is_user_banned(given_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare 
	_is_user_banned boolean:=null;
begin
	
	select u.is_banned into _is_user_banned from public.users u where u.id = given_user_id; 
	return _is_user_banned;
end;
$$;


ALTER FUNCTION public.is_user_banned(given_user_id uuid) OWNER TO doadmin;

--
-- Name: update_meme(uuid, text, boolean, public.meme_typename, text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.update_meme(given_id uuid, given_content text, given_is_audio boolean, given_meme_type public.meme_typename, given_img_url text, given_sound_url text) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_result record:=null;
begin
	
	update public.memes
	set
			"content" = given_content,
			is_audio = given_is_audio,
			meme_type = given_meme_type,
			img_url = given_img_url,
			sound_url = given_sound_url
	where id = given_id	
	returning memes.id, memes.created_at, memes.img_url, memes.sound_url, memes."content", memes.is_audio, memes.meme_type into _result;
	return _result;
end;
$$;


ALTER FUNCTION public.update_meme(given_id uuid, given_content text, given_is_audio boolean, given_meme_type public.meme_typename, given_img_url text, given_sound_url text) OWNER TO doadmin;

--
-- Name: update_meme_nofile(uuid, text, boolean, public.meme_typename); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.update_meme_nofile(given_id uuid, given_content text, given_is_audio boolean, given_meme_type public.meme_typename) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_result record:=null;
begin
	
	update public.memes
	set
			"content" = given_content,
			is_audio = given_is_audio,
			meme_type = given_meme_type
	where id = given_id	
	returning memes.id, memes.created_at, memes.img_url, memes.sound_url, memes."content", memes.is_audio, memes.meme_type into _result;
	return _result;
end;
$$;


ALTER FUNCTION public.update_meme_nofile(given_id uuid, given_content text, given_is_audio boolean, given_meme_type public.meme_typename) OWNER TO doadmin;

--
-- Name: update_puzzle(uuid, text, text, bigint, text, text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.update_puzzle(given_id uuid, given_img_url text, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_result record:=null;
begin
	
	update public.puzzles
	set
			img_url = given_img_url,
			ans = given_hashed_ans,
			puzzle_level = given_puzzle_level,
			title = given_title,
			info = given_info,
			info_link = given_info_link
	where id = given_id	
	returning puzzles.id, puzzles.created_at ,puzzles.img_url , puzzles.ans, puzzles.puzzle_level  , puzzles.title , puzzles.info , puzzles.info_link  into _result;
	return _result;
end;
$$;


ALTER FUNCTION public.update_puzzle(given_id uuid, given_img_url text, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) OWNER TO doadmin;

--
-- Name: update_puzzle_nofile(uuid, text, bigint, text, text, text); Type: FUNCTION; Schema: public; Owner: doadmin
--

CREATE FUNCTION public.update_puzzle_nofile(given_id uuid, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) RETURNS record
    LANGUAGE plpgsql
    AS $$
declare 
	_result record:=null;
begin
	
	update public.puzzles
	set
			ans = given_hashed_ans,
			puzzle_level = given_puzzle_level,
			title = given_title,
			info = given_info,
			info_link = given_info_link
	where id = given_id	
	returning puzzles.id, puzzles.created_at ,puzzles.img_url , puzzles.ans, puzzles.puzzle_level , puzzles.title , puzzles.info , puzzles.info_link   into _result;
	return _result;
end;
$$;


ALTER FUNCTION public.update_puzzle_nofile(given_id uuid, given_hashed_ans text, given_puzzle_level bigint, given_title text, given_info text, given_info_link text) OWNER TO doadmin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: memes; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public.memes (
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    img_url text,
    sound_url text,
    content text,
    is_audio boolean DEFAULT false,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    meme_type public.meme_typename DEFAULT 'failure'::public.meme_typename
);


ALTER TABLE public.memes OWNER TO doadmin;

--
-- Name: puzzle_attempts; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public.puzzle_attempts (
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid DEFAULT gen_random_uuid() NOT NULL,
    is_correct boolean DEFAULT false,
    submitted_ans text,
    puzzle_id uuid DEFAULT gen_random_uuid() NOT NULL,
    puzzle_level bigint DEFAULT '0'::bigint
);


ALTER TABLE public.puzzle_attempts OWNER TO doadmin;

--
-- Name: puzzles; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public.puzzles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    img_url text,
    ans text,
    puzzle_level bigint,
    title text,
    info text,
    info_link text
);


ALTER TABLE public.puzzles OWNER TO doadmin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username text DEFAULT ''::text NOT NULL,
    student_id text NOT NULL,
    user_type public.user_typename,
    curr_level bigint DEFAULT '0'::bigint,
    batch bigint,
    password_hash text,
    email text,
    shomobay_score double precision DEFAULT '0'::double precision,
    is_banned boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO doadmin;

--
-- Data for Name: memes; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public.memes (created_at, img_url, sound_url, content, is_audio, id, meme_type) FROM stdin;
\.


--
-- Data for Name: puzzle_attempts; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public.puzzle_attempts (submitted_at, user_id, is_correct, submitted_ans, puzzle_id, puzzle_level) FROM stdin;
\.


--
-- Data for Name: puzzles; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public.puzzles (id, created_at, img_url, ans, puzzle_level, title, info, info_link) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public.users (id, username, student_id, user_type, curr_level, batch, password_hash, email, shomobay_score, is_banned) FROM stdin;
\.


--
-- Name: memes memes_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.memes
    ADD CONSTRAINT memes_pkey PRIMARY KEY (id);


--
-- Name: puzzle_attempts puzzle_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.puzzle_attempts
    ADD CONSTRAINT puzzle_attempts_pkey PRIMARY KEY (submitted_at, user_id, puzzle_id);


--
-- Name: puzzles puzzles_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.puzzles
    ADD CONSTRAINT puzzles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: puzzle_attempts puzzle_attempts_puzzle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.puzzle_attempts
    ADD CONSTRAINT puzzle_attempts_puzzle_id_fkey FOREIGN KEY (puzzle_id) REFERENCES public.puzzles(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: puzzle_attempts puzzle_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public.puzzle_attempts
    ADD CONSTRAINT puzzle_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: memes; Type: ROW SECURITY; Schema: public; Owner: doadmin
--

ALTER TABLE public.memes ENABLE ROW LEVEL SECURITY;

--
-- Name: puzzle_attempts; Type: ROW SECURITY; Schema: public; Owner: doadmin
--

ALTER TABLE public.puzzle_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: puzzles; Type: ROW SECURITY; Schema: public; Owner: doadmin
--

ALTER TABLE public.puzzles ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: doadmin
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

