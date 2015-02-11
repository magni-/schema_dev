require 'schema_dev/gem'

describe SchemaDev::Gem do

  around(:each) do |example|
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        in_tmpdir do
          example.run
        end
      end
    end
  end

  context "builds" do

    Given(:user_name) { "My Name" }
    Given(:user_email) { "my_name@example.com" }

    Given {
      stub_request(:get, 'https://rubygems.org/api/v1/versions/schema_plus_core.json').to_return body: JSON.generate([
        { number: "1.0.0.pre", prerelease: true},
        { number: "0.2.1"},
        { number: "0.1.2"},
        { number: "0.1.1" },
      ])
      allow_any_instance_of(SchemaDev::Gem).to receive(:`).with("git config user.name").and_return user_name
      allow_any_instance_of(SchemaDev::Gem).to receive(:`).with("git config user.email").and_return user_email
    }

    When { SchemaDev::Gem.build gem_name }

    When(:gemspec) { File.read "#{gem_name}/#{gem_name}.gemspec" }

    Invariant { expect(gemspec).to include %q{"schema_plus_core", "~> 0.2", ">= 0.2.1"} }
    Invariant { expect(gemspec).to match %r{authors.*#{user_name}} }
    Invariant { expect(gemspec).to match %r{email.*#{user_email}} }

      context "flat gem" do
        Given(:gem_name) { "new_gem" }
        Then { expect(gemspec).to include %q{require 'new_gem/version'} }
        Then { expect(File.read "new_gem/lib/new_gem.rb").to include %q{SchemaMonkey.register NewGem} }
      end

      context "subdir gem" do
        Given(:gem_name) { "schema_plus_new_gem" }
        Then { expect(gemspec).to include %q{require 'schema_plus/new_gem/version'} }
        Then { expect(File.read "schema_plus_new_gem/lib/schema_plus_new_gem.rb").to include %q{require_relative 'schema_plus/new_gem.rb'} }
        Then { expect(File.read "schema_plus_new_gem/lib/schema_plus/new_gem.rb").to include %q{SchemaMonkey.register SchemaPlus::NewGem} }
      end
  end

  context "complains" do

    context "when no git user.name" do
      Given { allow_any_instance_of(SchemaDev::Gem).to receive(:`).with("git config user.name").and_return "" }
      Then { expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /who are you/i }
    end

    context "when in git worktree" do
      Given { expect_any_instance_of(SchemaDev::Gem).to receive(:system).with(/^git rev-parse/).and_return true }
      Then { expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /\bgit\b/ }
    end

    context "when gem directory exists" do
      Given { FileUtils.touch "new_gem" }
      Then { expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /exists/ }
    end
  end

end
