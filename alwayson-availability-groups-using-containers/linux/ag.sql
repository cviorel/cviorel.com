
:SETVAR node_01 "sql_node_01"
:SETVAR node_02 "sql_node_02"
:SETVAR node_03 "sql_node_03"
:SETVAR sa_user "sa"

:r /usr/config/miscpassword.env

/*
create login, master key and certificate on primary
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
USE master
GO

CREATE LOGIN dbm_login WITH PASSWORD = N'$(dbm_login_password)';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'$(encryption_password)';
go
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
TO FILE = '/var/opt/sqlserver/backup/dbm_certificate.cer'
WITH PRIVATE KEY (
        FILE = '/var/opt/sqlserver/backup/dbm_certificate.pvk',
        ENCRYPTION BY PASSWORD = N'$(encryption_password)'
    );
GO

/*
create login, master key and certificate on secondaries
*/
:CONNECT $(node_02) -U $(sa_user) -P $(sa_password)
CREATE LOGIN dbm_login WITH PASSWORD = N'$(dbm_login_password)';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'$(encryption_password)';
GO

CREATE CERTIFICATE dbm_certificate
    AUTHORIZATION dbm_user
    FROM FILE = '/var/opt/sqlserver/backup/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/var/opt/sqlserver/backup/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = N'$(encryption_password)'
);
GO


:CONNECT $(node_03) -U $(sa_user) -P $(sa_password)
CREATE LOGIN dbm_login WITH PASSWORD = N'$(dbm_login_password)';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'$(encryption_password)';
GO

CREATE CERTIFICATE dbm_certificate
    AUTHORIZATION dbm_user
    FROM FILE = '/var/opt/sqlserver/backup/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/var/opt/sqlserver/backup/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = N'$(encryption_password)'
);
GO


/*
create endpoints and XE session
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
GO

ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO

:CONNECT $(node_02) -U $(sa_user) -P $(sa_password)
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
GO

ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO

:CONNECT $(node_03) -U $(sa_user) -P $(sa_password)
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
GO

ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO

/*
create the AG
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
CREATE AVAILABILITY GROUP [AG1]
        WITH (CLUSTER_TYPE = NONE)
        FOR REPLICA ON
        N'sql_node_01'
            WITH (
            ENDPOINT_URL = N'tcp://sql_node_01.lab.local:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
                SEEDING_MODE = AUTOMATIC,
                FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
                ),
        N'sql_node_02'
            WITH (
            ENDPOINT_URL = N'tcp://sql_node_02.lab.local:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
                SEEDING_MODE = AUTOMATIC,
                FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
                ),
        N'sql_node_03'
            WITH (
            ENDPOINT_URL = N'tcp://sql_node_03.lab.local:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
                SEEDING_MODE = AUTOMATIC,
                FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
                );
GO

/*
join secondary nodes
*/
:CONNECT $(node_02) -U $(sa_user) -P $(sa_password)
ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE);
GO
ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
GO

:CONNECT $(node_03) -U $(sa_user) -P $(sa_password)
ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE);
GO
ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
GO

/*
create a TestAG database and add it to the AG
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
CREATE DATABASE TestAG
BACKUP DATABASE TestAG TO DISK = N'NUL:'
ALTER AVAILABILITY GROUP [AG1] ADD DATABASE TestAG


/*
put the nodes in sync commit mode
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
USE [master]
GO
ALTER AVAILABILITY GROUP [AG1]
MODIFY REPLICA ON N'sql_node_01' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
GO
ALTER AVAILABILITY GROUP [AG1]
MODIFY REPLICA ON N'sql_node_02' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
GO
ALTER AVAILABILITY GROUP [AG1]
MODIFY REPLICA ON N'sql_node_03' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
GO

/*
start AlwaysOn_health XE Session on node_01
*/
:CONNECT $(node_01) -U $(sa_user) -P $(sa_password)
DECLARE @Status bit;

SELECT
   @Status = iif(RS.name IS NULL, 0, 1)
FROM sys.dm_xe_sessions RS
RIGHT JOIN sys.server_event_sessions ES ON RS.name = ES.name
WHERE es.name = 'AlwaysOn_health'

IF( @Status = 0)
BEGIN
   print 'It was stopped, starting it...'

   ALTER EVENT SESSION AlwaysOn_health
   ON SERVER
   STATE = START;

   PRINT 'AlwaysOn_health XE Session started'
END
ELSE
BEGIN
   PRINT 'AlwaysOn_health is running!'
END
GO

/*
start AlwaysOn_health XE Session on node_02
*/
:CONNECT $(node_02) -U $(sa_user) -P $(sa_password)
DECLARE @Status bit;

SELECT
   @Status = iif(RS.name IS NULL, 0, 1)
FROM sys.dm_xe_sessions RS
RIGHT JOIN sys.server_event_sessions ES ON RS.name = ES.name
WHERE es.name = 'AlwaysOn_health'

IF( @Status = 0)
BEGIN
   print 'It was stopped, starting it...'

   ALTER EVENT SESSION AlwaysOn_health
   ON SERVER
   STATE = START;

   PRINT 'AlwaysOn_health XE Session started'
END
ELSE
BEGIN
   PRINT 'AlwaysOn_health is running!'
END
GO

/*
start AlwaysOn_health XE Session on node_03
*/
:CONNECT $(node_03) -U $(sa_user) -P $(sa_password)
DECLARE @Status bit;

SELECT
   @Status = iif(RS.name IS NULL, 0, 1)
FROM sys.dm_xe_sessions RS
RIGHT JOIN sys.server_event_sessions ES ON RS.name = ES.name
WHERE es.name = 'AlwaysOn_health'

IF( @Status = 0)
BEGIN
   print 'It was stopped, starting it...'

   ALTER EVENT SESSION AlwaysOn_health
   ON SERVER
   STATE = START;

   PRINT 'AlwaysOn_health XE Session started'
END
ELSE
BEGIN
   PRINT 'AlwaysOn_health is running!'
END
GO
