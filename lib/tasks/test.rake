# frozen_string_literal: true

namespace :test do # rubocop:disable Metrics/BlockLength
  desc "Run tests with SQLite3"
  task :sqlite3 do
    ENV["DB_ADAPTER"] = "sqlite3"
    Rake::Task["test"].invoke
    Rake::Task["test"].reenable
  end

  desc "Run tests with PostgreSQL"
  task :postgresql do
    sh "docker-compose up -d postgres"
    wait_for_postgres

    begin
      ENV["DB_ADAPTER"] = "postgresql"
      Rake::Task["test"].invoke
      Rake::Task["test"].reenable
    ensure
      sh "docker-compose down"
    end
  end

  desc "Run tests with MySQL"
  task :mysql2 do
    sh "docker-compose up -d mysql"
    wait_for_mysql

    begin
      ENV["DB_ADAPTER"] = "mysql2"
      Rake::Task["test"].invoke
      Rake::Task["test"].reenable
    ensure
      sh "docker-compose down"
    end
  end

  desc "Run tests with all adapters (SQLite3, PostgreSQL, MySQL)"
  task all: %i[sqlite3 postgresql mysql2]

  def wait_for_postgres
    retries = 10
    begin
      sh "docker-compose exec -T postgres pg_isready -U postgres"
    rescue StandardError
      retries -= 1

      raise "PostgreSQL is not ready after several attempts." if retries < 1

      sleep 2
      retry
    end
  end

  def wait_for_mysql
    retries = 10
    begin
      sh "docker-compose exec -T mysql mysqladmin ping -h 127.0.0.1 --silent"
    rescue StandardError
      retries -= 1

      raise "MySQL is not ready after several attempts." if retries < 1

      sleep 2
      retry
    end
  end
end
