require "file_utils"

class Backup
  TASK_DIR = ENV["NOMAD_TASK_DIR"]

  property tag : String

  def initialize(@tag)
  end

  def run
    convert_config
    sync
    backup
  end

  def convert_config
    File.open("#{TASK_DIR}/running.yaml", "w+") do |dest|
      Process.run "remarshal", error: STDERR, output: dest, args: [
        "--if", "json",
        "--of", "yaml",
        "#{TASK_DIR}/node-config.json",
      ]
    end
  end

  def sync
    process = Process.new "jormungandr", error: STDERR, output: STDOUT, args: [
      "--storage", "#{TASK_DIR}/storage",
      "--config", "#{TASK_DIR}/running.yaml",
      "--genesis-block", "#{TASK_DIR}/block0.bin/block0.bin",
    ]

    wait_for_tip
  ensure
    HTTP::Client.get "http://127.0.0.1:9000/api/v0/shutdown"
    sleep 5
    Process.kill Signal::INT, process.pid if process && process.exists?
  end

  # Wait until we are synchronized...
  # The way we measure this is unfortunately not ideal, but should be a
  # good approximation if this runs continuously and without a huge delta.
  #
  # TODO: establish a source of truth (querying the passive node for its tip?)
  def wait_for_tip
    loop do
      sleep 5

      stats = NodeStats.from_json(HTTP::Client.get("http://127.0.0.1:9000/api/v0/node/stats").body)

      pp! stats

      if lrbs = stats.last_received_block_time
        if lrbs == stats.last_block_time
          sleep 30
          return
        end
      end
    end
  end

  def backup
    FileUtils.mkdir_p "/tmp"

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "backup", "--verbose", "--tag", tag, "#{TASK_DIR}/storage"
    ]

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "forget", "--prune", "--keep-last", "100"
    ]
  end
end

class NodeStats
  include JSON::Serializable

  property version : String

  property state : String

  @[JSON::Field(key: "blockRecvCnt")]
  property block_recv_cnt : Int32

  @[JSON::Field(key: "lastBlockContentSize")]
  property last_block_content_size : Int32

  @[JSON::Field(key: "lastBlockDate")]
  property last_block_date : String

  @[JSON::Field(key: "lastBlockFees")]
  property last_block_fees : Int32

  @[JSON::Field(key: "lastBlockHash")]
  property last_block_hash : String

  @[JSON::Field(key: "lastBlockHeight")]
  property last_block_height : String

  @[JSON::Field(key: "lastBlockSum")]
  property last_block_sum : Int32

  @[JSON::Field(key: "lastBlockTime")]
  property last_block_time : String

  @[JSON::Field(key: "lastBlockTx")]
  property last_block_tx : Int32

  @[JSON::Field(key: "lastReceivedBlockTime")]
  property last_received_block_time : String?

  @[JSON::Field(key: "peerAvailableCnt")]
  property peer_available_cnt : Int32

  @[JSON::Field(key: "peerConnectedCnt")]
  property peer_connected_cnt : Int32

  @[JSON::Field(key: "peerQuarantinedCnt")]
  property peer_quarantined_cnt : Int32

  @[JSON::Field(key: "peerTotalCnt")]
  property peer_total_cnt : Int32

  @[JSON::Field(key: "peerUnreachableCnt")]
  property peer_unreachable_cnt : Int32

  @[JSON::Field(key: "txRecvCnt")]
  property tx_recv_cnt : Int32

  property uptime : Int32
end
