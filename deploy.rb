#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

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

JOBS = JSON.parse(`cue list`)

def sh!(*args)
  system(*args) or raise("failed to run #{args.join(' ')}")
end

def cue(*args, job_name: nil)
  JOBS.each do |job|
    if !job_name || job == job_name
      p "cue -t job=#{job} #{args.join(' ')}"
      sh!('cue', '-t', "job=#{job}", *args)
    end
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
  cue 'run', job_name: job
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
