#!/bin/sh

ERLANG_VERSION=18.2
ELIXIR_VERSION=1.2.4

# Note: password is for postgres user "postgres"
POSTGRES_DB_PASS=postgres
POSTGRES_VERSION=9.3

# Set language and locale
apt-get install -y language-pack-en
locale-gen --purge en_US.UTF-8
echo "LC_ALL='en_US.UTF-8'" >> /etc/environment
dpkg-reconfigure locales

# Install basic packages
# inotify is installed because it's a Phoenix dependency
apt-get -qq update
apt-get install -y \
wget \
git \
unzip \
build-essential \
ntp \
inotify-tools

# Install Erlang
echo "deb http://packages.erlang-solutions.com/ubuntu trusty contrib" >> /etc/apt/sources.list && \
apt-key adv --fetch-keys http://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc && \
apt-get -qq update && \
apt-get install -y \
erlang=1:$ERLANG_VERSION \

# Install Elixir
cd / && mkdir elixir && cd elixir && \
wget -q https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip && \
unzip Precompiled.zip && \
rm -f Precompiled.zip && \
ln -s /elixir/bin/elixirc /usr/local/bin/elixirc && \
ln -s /elixir/bin/elixir /usr/local/bin/elixir && \
ln -s /elixir/bin/mix /usr/local/bin/mix && \
ln -s /elixir/bin/iex /usr/local/bin/iex

# Install local Elixir hex and rebar for the vagrant user
su - vagrant -c '/usr/local/bin/mix local.hex --force && /usr/local/bin/mix local.rebar --force'

# Postgres
apt-get -y install postgresql-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION

PG_CONF="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
echo "client_encoding = utf8" >> "$PG_CONF" # Set client encoding to UTF8
service postgresql restart

cat << EOF | su - postgres -c psql
ALTER USER postgres WITH ENCRYPTED PASSWORD '$POSTGRES_DB_PASS';
EOF

# Install nodejs and npm
curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -
apt-get install -y \
nodejs

# Install imagemagick
apt-get install -y imagemagick

# If seeds.exs exists we assume it is a Phoenix project
if [ -f /vagrant/priv/repo/seeds.exs ]
  then
    # Set up and migrate database
    su - vagrant -c 'cd /vagrant && mix deps.get && mix ecto.create && mix ecto.migrate'
    # Run Phoenix seed data script
    su - vagrant -c 'cd /vagrant && mix run priv/repo/seeds.exs'
fi

# Install Hex and Rebar
mix local.hex --force 
mix local.rebar --force 

# Install fwup (required by `mix firmware`)
wget https://github.com/fhunleth/fwup/releases/download/v0.7.0/fwup_0.7.0_amd64.deb -O /tmp/fwup.deb
sudo dpkg -i /tmp/fwup.deb

# Install squashfs-tools (required by `mix firmware`)
sudo apt-get -qq update && sudo apt-get install -y squashfs-tools

# Install Nerves Bootstrap
mix archive.install --force https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez

cd /home/vagrant
mkdir projects
cd projects

# Create 1st project
mix nerves.new nerves_meetup_rpi --target rpi
cd nerves_meetup_rpi
mix deps.get && mix compile && mix firmware
cd ..

# Create 2nd project
mix nerves.new nerves_meetup_rpi2 --target rpi2
cd nerves_meetup_rpi2
mix deps.get && mix compile && mix firmware
cd ..

# Create 3rd project
mix nerves.new nerves_meetup_rpi3 --target rpi3
cd nerves_meetup_rpi3
mix deps.get && mix compile && mix firmware
cd ..
