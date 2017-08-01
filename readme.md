An unusable PostgreSQL driver written in Elixir

This project is just a few hours old and is completely unusable.

The goal of this driver is to focus on speed and simplicity. Some very early
numbers show a ~25% speed increase over Postgrex. A secondary goal is to make
the library easier to use, specifically around prepared statements and extending
the library with custom types.

# Contributing

`make db` will create a `pgex_test` database on your locally running PostgreSQL
server. (it'll drop it first, if it exists).

`make schema` will create the test shemas within this database.

`mix test` will run the tests.
