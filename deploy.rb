#! /usr/bin/env nix-shell
#! nix-shell -i ruby -p "ruby.withPackages (ps: with ps; [ rest-client ])
# frozen_string_literal: true

# Hack to avoid cookie issue
module HTTP
  class CookieJar
    def cookies(*args)
      []
    end
  end
end

require 'json'
require 'rest-client'

# Example usage:
# With NOMAD_NAMESPACE set:
# ./deploy.rb run leader-0
# ./deploy.rb run
# ./deploy.rb render
# ./deploy.rb stop
# ./deploy.rb reset

%w[NOMAD_NAMESPACE CONSUL_HTTP_TOKEN NOMAD_ADDR NOMAD_TOKEN].each do |key|
  ENV[key] || raise("missing environment variable #{key}")
end

NAMESPACE = ENV.fetch('NOMAD_NAMESPACE', 'catalyst-dryrun')
ENV['NOMAD_NAMESPACE'] = NAMESPACE

OUTPUT = JSON.parse(`cue export`)
JOBS = OUTPUT.fetch('rendered').fetch(NAMESPACE).keys

def sh!(*args)
  system(*args) or raise("failed to run #{args.join(' ')}")
end

def run(job_name: nil)
  JOBS.each do |job|
    next if job_name && job != job_name

    body = OUTPUT.fetch('rendered').fetch(NAMESPACE).fetch(job)
    body['Job']['ConsulToken'] = ENV.fetch('CONSUL_HTTP_TOKEN')
    response = RestClient.post "#{ENV.fetch('NOMAD_ADDR')}/v1/jobs", body.to_json, {
      'X-Nomad-Token': ENV.fetch('NOMAD_TOKEN'),
      'X-Vault-Token': `vault print token`.strip
    }
    puts "Response: #{response.code}"
    pp JSON.parse(response.body)
  end
end


def plan(job_name: nil)
  JOBS.each do |job|
    next if job_name && job != job_name

    body = OUTPUT.fetch('rendered').fetch(NAMESPACE).fetch(job)
    body['Job']['ConsulToken'] = ENV.fetch('CONSUL_HTTP_TOKEN')
    body['Diff'] = true
    id = body.fetch('Job').fetch('ID')
    response = RestClient.post "#{ENV.fetch('NOMAD_ADDR')}/v1/job/#{id}/plan", body.to_json, {
      'X-Nomad-Token': ENV.fetch('NOMAD_TOKEN'),
      'X-Vault-Token': `vault print token`.strip
    }
    puts "Response: #{response.code}"
    pp JSON.parse(response.body)
  end
end

def nomad(*args, job_name: nil)
  threads = []
  JOBS.each do |job|
    if !job_name || job == job_name
      p "nomad #{args.join(' ')} #{job}"
      threads << Thread.new { sh!('nomad', *args, job) }
    end
  end
  threads.each(&:join)
end

job = ARGV[1]

case ARGV[0]
when 'list'
  pp JOBS
when 'run'
  run job_name: job
when 'plan'
  plan job_name: job
when 'render'
  cue 'render', job_name: job
when 'stop'
  nomad 'job', 'stop', '-purge', job_name: job
when 'reset'
  p :reset
  system('./scripts/reset.sh')
  # TODO
else
  warn 'first argument needs to be run|stop|reset'
  exit 1
end
