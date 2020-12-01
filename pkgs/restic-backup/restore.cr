class Restore
  TASK_DIR = ENV["NOMAD_TASK_DIR"]

  property tag : String

  def initialize(@tag)
  end

  def run
    Process.run "restic", error: STDERR, output: STDOUT, args: [
      "restore", "latest",
      "--tag", tag,
      "--target", "#{TASK_DIR}/storage"
    ]
  end
end

alias Snapshots = Array(Snapshot)

class Snapshot
  include JSON::Serializable

  property time : String
  property parent : String
  property tree : String
  property paths : Array(String)
  property hostname : String
  property username : String
  property uid : Int32
  property gid : Int32
  property id : String
  property short_id : String
  property tags : Array(String)?
end
