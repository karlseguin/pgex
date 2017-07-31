F=
export PGOPTIONS = --client-min-messages=WARNING

# run tests
t:
	mix test ${F}

# create the test database
db:
	-psql -d postgres -c 'drop database pgex_test'
	psql -d postgres -c 'create database pgex_test'

# creates the test database schema
schema:
	find sql/*.sql -print0 | xargs -0 -n1 -L 1 psql -v ON_ERROR_STOP=1 -q -d pgex_test -f
