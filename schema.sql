CREATE TABLE users
(
    ID INT(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    secret VARCHAR(32) NOT NULL
);
CREATE UNIQUE INDEX secret ON users (secret);
CREATE UNIQUE INDEX users_username_uindex ON users (username);
CREATE TABLE servers
(
    ID INT(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_ID INT(11) COMMENT 'Falls NULL ist es ein generischer Dienst bspw. IRC',
    server_url VARCHAR(100) NOT NULL,
    server_id INT(11) COMMENT 'Für Teamspeak. die virtual server ID',
    server_port INT(5) NOT NULL,
    server_type VARCHAR(32) NOT NULL,
    user_name VARCHAR(64) NOT NULL,
    user_password VARCHAR(255),
    status TINYINT(1) DEFAULT '1',
    realname VARCHAR(255) DEFAULT 'Bridgie McBridgeface'
);
CREATE UNIQUE INDEX servers_ID_uindex ON servers (ID);
CREATE UNIQUE INDEX servers_server_url_uindex ON servers (server_url);
CREATE TABLE ignorelist
(
    ID INT(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_ID INT(11) DEFAULT '11' NOT NULL,
    username VARCHAR(64)
);
CREATE UNIQUE INDEX ignorelist_ID_uindex ON ignorelist (ID);
CREATE TABLE channels
(
    ID INT(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_ID INT(11) NOT NULL COMMENT 'die ID des Users dem der Channel gehört',
    server_ID INT(11) DEFAULT '11' NOT NULL,
    channel_name VARCHAR(64) NOT NULL,
    channel_password VARCHAR(255),
    enabled TINYINT(1) DEFAULT '1'
);
CREATE UNIQUE INDEX channels_ID_uindex ON channels (ID);
CREATE TABLE quota
(
    ID INT(11),
    user_ID INT(11),
    server_type VARCHAR(32),
    max INT(11)
);