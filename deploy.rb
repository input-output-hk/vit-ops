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

NAMESPACE = ENV.fetch('NOMAD_NAMESPACE', 'catalyst-dryrun')
ENV['NOMAD_NAMESPACE'] = NAMESPACE

def json
  JSON.parse(`dhall-to-json --file ./deploy.dhall`)
end

def levant(*args, job_name: nil)
  json.each do |namespace, nvalues|
    next if namespace != NAMESPACE

    jobs = nvalues.delete 'jobs'
    vars = { namespace: namespace }.merge nvalues
    jobs.each do |job|
      next if job_name && job['name'] != job_name

      template = job.delete 'template'
      vars.merge! job
      flags = vars.flat_map { |k, v| ['-var', "#{k}=#{v}"] }
      system('levant', *args, *flags, template)
    end
  end
end

def nomad(*args, job_name: nil)
  threads = []
  json.each do |namespace, nvalues|
    next if namespace != NAMESPACE

    nvalues['jobs'].each do |job|
      next if job_name && job['name'] != job_name

      threads << Thread.new{ system('nomad', *args, job['name']) }
    end
  end
  threads.each(&:join)
end

job = ARGV[1]

case ARGV[0]
when 'run'
  levant 'deploy', job_name: job
when 'render'
  levant 'render', job_name: job
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
