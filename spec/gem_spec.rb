require 'schema_dev/gem'

describe SchemaDev::Gem do
  before(:each) do
    stub_request(:get, 'https://rubygems.org/api/v1/versions/schema_monkey.json').to_return body: JSON.generate([{ built_at: Time.now, number: "0.1.2"}])
  end

  around(:each) do |example|
    silence_stream(STDOUT) do
      example.run
    end
  end

  it "creates gemspec" do
    in_tmpdir do
      expect{SchemaDev::Gem.build("NewGem")}.not_to raise_error
      gemspec = File.read "new_gem/new_gem.gemspec"
      expect(gemspec).to include %q{"schema_monkey", "~> 0.1", ">= 0.1.2"}
    end
  end

  context "complains" do

    around(:each) do |example|
      silence_stream(STDERR) do
        example.run
      end
    end

    it "when no git user.name" do
      in_tmpdir do
        expect_any_instance_of(SchemaDev::Gem).to receive(:`).with("git config user.name").and_return ""
        expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /who are you/i
      end
    end

    it "when in git worktree" do
      in_tmpdir do
        system('git init')
        expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /\bgit\b/
      end
    end

    it "when gem directory exists" do
      in_tmpdir do
        FileUtils.touch "new_gem"
        expect{SchemaDev::Gem.build("NewGem")}.to raise_error SystemExit, /exists/
      end
    end
  end

end
