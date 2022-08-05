create database atc;

use atc;

-- following are the tables of the database 

create table if not exists flight_info(
req_time timestamp not null,
plane_id char(5) not null,
no_of_passengers int unsigned not null,
primary key (plane_id)
);

create table if not exists atc_info(
alotted_time timestamp not null,
plane_id char(5) not null references flight_info,
primary key (alotted_time)
);

-- following is the procedure to inset data into database 

delimiter //
create definer = root@localhost procedure insertion (in input_req_time timestamp, in input_plane_id char(5) , in input_no_of_passengers int unsigned)
reads sql data
deterministic
sql security invoker
comment 'insertion is done based on input- req_time,plane_id,no_of_passengers'
begin
declare t timestamp;
start transaction;
insert into atc.flight_info (req_time,plane_id,no_of_passengers) values (input_req_time,input_plane_id,input_no_of_passengers);
set t = input_req_time;
call scheduler(t);
insert into atc.atc_info (alotted_time,plane_id) values (t , input_plane_id);
commit;
end //
delimiter ;

-- following is the procedure to delete 

delimiter //
create definer = root@localhost procedure deletion (in input_plane_id char(5))
reads sql data
deterministic
sql security invoker
comment 'deletion is done based on input- plane_id'
begin
start transaction;
delete from flight_info where plane_id = input_plane_id;
delete from atc_info where atc_info.plane_id = input_plane_id;
commit;
end //
delimiter ;

-- following is the procedure to update 

delimiter //
create definer = root@localhost procedure updating (in input_req_time timestamp, in input_plane_id char(5))
reads sql data
deterministic
sql security invoker
comment 'update is done based on input- req_time,plane_id'
begin
declare n int;
start transaction;
set n = (select no_of_passengers from flight_info where plane_id = input_plane_id);
call deletion (input_plane_id);
call insertion (input_req_time,input_plane_id,n);
commit;
end //
delimiter ;

-- the recursion depth is set to max as the procedure (scheduler) uses recursion

SET @@SESSION.max_sp_recursion_depth = 255;

-- following is the scheduler procedure which takes an inout parameter and modifies it such that the modified parameter now contains actual alotted time   

delimiter $$
create definer = root@localhost procedure scheduler (inout input_req_time timestamp)
modifies sql data
deterministic
sql security invoker
begin
declare cut int;
declare new_time time;
declare t4 time;

create table t1 as (select timediff(input_req_time,alotted_time) as time_diff from atc_info where timediff(input_req_time,alotted_time) > '0:0:0');
set cut = (select count(*) from t1);
if cut > 0 then
set t4 = (select min(t1.time_diff) from t1);
drop table if exists t1;
if t4 < '00:05:00' then
set new_time = subtime('00:05:00',t4);
set input_req_time = addtime(input_req_time,new_time);
end if ;
end if ;
drop table if exists t1;

create table t2 as (select timediff(alotted_time,input_req_time) as time_diff from atc_info where timediff(alotted_time,input_req_time) >= '0:0:0');
set cut = (select count(*) from t2);
if cut > 0 then
set t4 = (select min(t2.time_diff) from t2);
drop table if exists t2;
if t4 < '00:05:00' then
set input_req_time = addtime(input_req_time,t4);
set input_req_time = addtime(input_req_time,'00:05:00');
call scheduler (input_req_time);
end if ;
end if ;
drop table if exists t2;

end $$
delimiter ;

-- following is the sample data which can be inserted in the database to populate it

 call insertion('2022-04-20 10:15:00','D2K01',100); 
 call insertion('2022-04-20 10:14:11','D2K02',200);  
 call insertion('2022-04-20 10:20:12','D2K03',72);  
 call insertion('2022-04-20 10:50:18','D2K04',106);
 call insertion('2022-04-20 11:30:19','D2N01',104);
 call insertion('2022-04-20 11:45:07','D2N02',142);
 call insertion('2022-04-20 11:49:00','D2A01',150);
 call insertion('2022-04-20 11:50:00','D2C01',17);
 

-- following procedure are made to insert , delete and update data in the atc database;

call deletion('D2K05');                                 -- pass the plane id (plane_id) 
call updating('2022-08-04 10:20:43','D2K07');           -- pass the new request time (req_time) and plane id (plane_id)
call insertion('2022-04-20 10:22:01','D2K05',100);      -- pass the request time (req_time) , plane id (plane_id) and number of passengers (no_of_passengers) 

-- following query is to check the database (it shows that the difference between the alotted time is atleast 5 min) 
 
select * from flight_info order by req_time;
select * from atc_info order by alotted_time;
