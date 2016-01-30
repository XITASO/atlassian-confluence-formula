require "serverspec"

set :backend, :exec

describe service("atlassian-confluence") do
  it { should be_enabled }
  it { should be_running }
end

describe port("8009") do
  it { should be_listening }
end

describe port("8090") do
  it { should be_listening }
end

describe command('curl -L localhost:8090') do
  its(:stdout) { should contain('Set up Confluence') }
end
