CREATE TABLE lists (
id serial PRIMARY KEY,
name text UNIQUE NOT NULL
);

CREATE TABLE todos (
id serial PRIMARY KEY,
name text NOT NULL,
list_id integer NOT NULL REFERENCES lists(id),
completed boolean NOT NULL DEFAULT false
);


 CREATE TABLE authors (
  id serial PRIMARY KEY,
  name varchar(100) NOT NULL
);
CREATE TABLE
 CREATE TABLE books (
  id serial PRIMARY KEY,
  title varchar(100) NOT NULL,
  isbn char(13) UNIQUE NOT NULL,
  author_id int REFERENCES authors(id)
);