require "json"
require "http/client"
require "option_parser"

enum Action
  Backup
  Restore
end

action = Action::Backup
tag = ""

op = OptionParser.new do |o|
  o.banner = "backup NOMAD_TASK_DIR/storage using restic"
  o.on("-h", "--help", "Display this help"){ puts o; exit 0 }
  o.on("-b", "--backup", "Backup"){ action = Action::Backup }
  o.on("-r", "--restore", "Restore"){ action = Action::Restore }
  o.on("-t", "--tag=TAG", "Snapshot tag"){|v| tag = v }
end

op.parse

def fail(msg)
  STDERR.puts msg
  exit 1
end

fail "--tag must be set" if tag.empty?
fail "NOMAD_TASK_DIR must be set" unless ENV["NOMAD_TASK_DIR"]?
fail "RESTIC_REPOSITORY must be set" unless ENV["RESTIC_REPOSITORY"]?
fail "RESTIC_PASSWORD must be set" unless ENV["RESTIC_PASSWORD"]?

require "./*"

case action
when Action::Backup
  Backup.new(tag).run
when Action::Restore
  Restore.new(tag).run
end
