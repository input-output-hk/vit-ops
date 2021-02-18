package types

import (
	"time"
	"list"
)

#json: {
	Job: {
		Namespace: string
		ID:        Name
		Name:      string
		Type:      *"service" | "system" | "batch"
		Priority:  uint | *50
		Datacenters: [...string]
		TaskGroups: [...TaskGroup]
		Constraints: [...Constraint]
		ConsulToken: *null | string
		Vault:       *null | #json.Vault
	}

	Constraint: {
		LTarget: string | *null
		RTarget: string
		Operand: "regexp" | "set_contains" | "distinct_hosts" | "distinct_property" | "=" | "==" | "is" | "!=" | "not" | ">" | ">=" | "<" | "<="
	}

	Affinity: {
		LTarget: string
		RTarget: string
		Operand: "regexp" | "set_contains_all" | "set_contains" | "set_contains_any" | "=" | "==" | "is" | "!=" | "not" | ">" | ">=" | "<" | "<=" | "version"
		Weight:  uint & !=0 & >=-100 & <=100
	}

	RestartPolicy: {
		Attempts: uint
		Interval: uint
		Delay:    uint
		Mode:     "delay" | "fail"
	}

	Spread: {
		Attribute:    string
		SpreadTarget: null | {
			Value:   string | *""
			Percent: uint | *0
		}
	}

	Volume: {
		Name:     string
		Type:     *null | "host" | "csi"
		Source:   string
		ReadOnly: bool | *false
		MountOptions: {
			FsType:     *null | string
			mountFlags: *null | string
		}
	}

	ReschedulePolicy: *null | {
		Attempts:      uint | *10
		DelayFunction: "constant" | "exponential" | *"fibonacci"
		Delay:         uint | *30000000000
		Interval:      uint | *0
		MaxDelay:      uint | *3600000000000
		Unlimited:     bool | *true
	}

	Restart: {
		Attempts: uint
		Delay:    uint
		Interval: uint
		Mode:     "fail" | "delay"
	}

	TaskGroup: {
		Affinities: [...Affinity]
		Constraints: [...Constraint]
		Count: int & >0 | *1
		Meta: [string]: string
		Name:          string
		RestartPolicy: *null | #json.RestartPolicy
		Restart:       #json.Restart
		Services: [...Service]
		ShutdownDelay: uint | *0
		Spreads: [...#json.Spread]
		Tasks: [...Task]
		Volumes: [string]: #json.Volume
		ReschedulePolicy: #json.ReschedulePolicy
		EphemeralDisk:    *null | {
			Migrate: bool
			Size:    uint
			Sticky:  bool
		}
		Migrate: *null | {
			HealthCheck:     *"checks" | "task_states"
			HealthyDeadline: uint | *500000000000
			MaxParallel:     uint | *1
			MinHealthyTime:  uint | *10000000000
		}
		Update: *null | {
			MaxParallel:     uint | *1
			HealthCheck:     *"checks" | "task_states" | "manual"
			MinHealthyTime:  uint | *10000000000
			HealthyDeadline: uint | *180000000000
			AutoRevert:      bool | *false
			Canary:          uint | *0
		}
		Networks: [...#json.Network]
		StopAfterClientDisconnect: *null | uint
		Scaling:                   null
		Vault:                     *null | #json.Vault
		RestartPolicy:             null
	}

	Port: {
		Label:       string
		Value:       uint | *null // used for static ports
		To:          uint | *null
		HostNetwork: string | *""
	}

	Network: {
		Mode:          *"host" | "bridge"
		Device:        string | *""
		CIDR:          string | *""
		IP:            string | *""
		DNS:           null
		ReservedPorts: *null | [...#json.Port]
		DynamicPorts:  *null | [...#json.Port]
		MBits:         null
	}

	ServiceCheck: {
		AddressMode:            *"host" | "driver" | "alloc"
		Args:                   [...string] | *null
		CheckRestart:           #json.CheckRestart
		Command:                string | *""
		Expose:                 false
		FailuresBeforeCritical: uint | *0
		Header:                 null
		Id:                     string | *""
		InitialStatus:          ""
		Interval:               10000000000
		Method:                 ""
		Name:                   string | *""
		Path:                   string
		PortLabel:              string
		Protocol:               string | *""
		SuccessBeforePassing:   0
		TaskName:               string | *""
		Timeout:                uint
		TLSSkipVerify:          bool | *false
		Type:                   "http" | "tcp" | "script"
	}

	CheckRestart: *null | {
		Limit:          uint | *0
		Grace:          uint | *10000000000
		IgnoreWarnings: bool | *false
	}

	LogConfig: *null | {
		MaxFiles:      uint & >0
		MaxFileSizeMB: uint & >0
	}

	Service: {
		Id:   string | *""
		Name: string
		Tags: [...string]
		CanaryTags:        [...string] | *[]
		EnableTagOverride: bool | *false
		PortLabel:         string
		AddressMode:       "host" | "bridge"
		Checks: [...ServiceCheck]
		CheckRestart: #json.CheckRestart
		Connect:      null
		Meta: [string]: string
		TaskName: string | *""
	}

	Task: {
		Name:   string
		Driver: "exec" | "docker" | "nspawn"
		Config: {
			args:    [...string] | *[]
			command: string
			flake:   string
		}
		Constraints: [...Constraint]
		Affinities: [...Affinity]
		Env: [string]: string
		Services: [...Service]
		Resources: {
			CPU:      uint & >=100 | *100
			MemoryMB: uint & >=32 | *300
			DiskMB:   *null | uint
		}
		Meta: {}
		RestartPolicy: null
		ShutdownDelay: uint | *0
		User:          string | *""
		Lifecycle:     null
		KillTimeout:   null
		LogConfig:     #json.LogConfig
		Artifacts: [...#json.Artifact]
		Templates: [...#json.Template]
		DispatchPayload: null
		VolumeMounts: [...#json.VolumeMount]
		Leader:          bool | *false
		KillSignal:      string
		ScalingPolicies: null
		Vault:           *null | #json.Vault
	}

	VolumeMount: {
		Destination:     string
		PropagationMode: string
		ReadOnly:        bool
		Volume:          string
	}

	Artifact: {
		GetterSource: string
		GetterOptions: [string]: string
		GetterHeaders: [string]: string
		GetterMode:   *"any" | "file" | "dir"
		RelativeDest: string
	}

	Template: {
		SourcePath:   string | *""
		DestPath:     string
		EmbeddedTmpl: string
		ChangeMode:   *"restart" | "noop" | "signal"
		ChangeSignal: string | *""
		Splay:        uint | *5000000000
		Perms:        *"0644" | =~"^[0-7]{3}$"
		LeftDelim:    string
		RightDelim:   string
		Envvars:      bool
	}

	Vault: {
		ChangeMode:   "noop" | *"restart" | "signal"
		ChangeSignal: string | *""
		Env:          bool | *true
		Namespace:    string | *""
		Policies:     list.MinItems(1)
	}
}

let durationType = string & =~"^[1-9]\\d*[hms]$"

toJson: #json.Job & {
	#job:        #stanza.job
	#jobName:    string
	Name:        #jobName
	Datacenters: #job.datacenters
	Namespace:   #job.namespace
	Type:        #job.type

	if #job.vault != null {
		Vault: {
			ChangeMode:   #job.vault.change_mode
			ChangeSignal: #job.vault.change_signal
			Env:          #job.vault.env
			Namespace:    #job.vault.namespace
			Policies:     #job.vault.policies
		}
	}

	Constraints: [ for c in #job.constraints {
		LTarget: c.attribute
		RTarget: c.value
		Operand: c.operator
	}]

	TaskGroups: [ for tgName, tg in #job.group {
		Name: tgName

		Count: tg.count

		if tg.ephemeral_disk != null {
			EphemeralDisk: {
				Size:    tg.ephemeral_disk.size
				Migrate: tg.ephemeral_disk.migrate
				Sticky:  tg.ephemeral_disk.sticky
			}
		}

		// only one network can be specified at group level, and we never use
		// deprecated task level ones.
		Networks: [{
			Mode: tg.network.mode
			ReservedPorts: [
				for nName, nValue in tg.network.port if nValue.static != null {
					Label:       nName
					Value:       nValue.static
					To:          nValue.to
					HostNetwork: nValue.host_network
				}]
			DynamicPorts: [
				for nName, nValue in tg.network.port if nValue.static == null {
					Label:       nName
					Value:       nValue.static
					To:          nValue.to
					HostNetwork: nValue.host_network
				}]
		}]

		Restart: {
			Attempts: tg.restart.attempts
			Delay:    time.ParseDuration(tg.restart.delay)
			Interval: time.ParseDuration(tg.restart.interval)
			Mode:     tg.restart.mode
		}

		Services: [ for sName, s in tg.service {
			Name:         sName
			TaskName:     s.task
			Tags:         s.tags
			AddressMode:  s.address_mode
			CheckRestart: s.check_restart
			Checks: [ for cName, c in s.check {
				{
					Type:      c.type
					PortLabel: c.port
					Interval:  time.ParseDuration(c.interval)
					Path:      c.path
					Timeout:   time.ParseDuration(c.timeout)
				}
			}]
			PortLabel: s.port
			Meta:      s.meta
		}]

		Tasks: [ for tName, t in tg.task {
			Name:       tName
			Driver:     t.driver
			Config:     t.config
			Env:        t.env
			KillSignal: t.kill_signal

			Resources: {
				CPU:      t.resources.cpu
				MemoryMB: t.resources.memory
			}

			Templates: [ for tplName, tpl in t.template {
				DestPath:     tplName
				EmbeddedTmpl: tpl.data
				SourcePath:   tpl.source
				Envvars:      tpl.env
				ChangeMode:   tpl.change_mode
				ChangeSignal: tpl.change_signal
				LeftDelim:    tpl.left_delimiter
				RightDelim:   tpl.right_delimiter
			}]

			Artifacts: [ for artName, art in t.artifact {
				GetterHeaders: art.headers
				GetterMode:    art.mode
				GetterOptions: art.options
				GetterSource:  art.source
				RelativeDest:  artName
			}]

			if t.vault != null {
				Vault: {
					ChangeMode:   t.vault.change_mode
					ChangeSignal: t.vault.change_signal
					Env:          t.vault.env
					Namespace:    t.vault.namespace
					Policies:     t.vault.policies
				}
			}

			VolumeMounts: [ for volName, vol in t.volume_mount {
				Destination:     vol.destination
				PropagationMode: "private"
				ReadOnly:        vol.read_only
				Volume:          volName
			}]
		}]

		if tg.vault != null {
			Vault: {
				ChangeMode:   tg.vault.change_mode
				ChangeSignal: tg.vault.change_signal
				Env:          tg.vault.env
				Namespace:    tg.vault.namespace
				Policies:     tg.vault.policies
			}
		}

		for volName, vol in tg.volume {
			Volumes: "\(volName)": {
				Name:     volName
				Type:     vol.type
				Source:   vol.source
				ReadOnly: vol.read_only
				MountOptions: {
					FsType:     vol.mount_options.fs_type
					mountFlags: vol.mount_options.mount_flags
				}
			}
		}
	}]
}

#stanza: {
	job: {
		datacenters: [...string]
		namespace: string
		type:      "batch" | *"service" | "system"
		constraints: [...#stanza.constraint]
		group: [string]: #stanza.group & {#type: type}
		update: #stanza.update
		vault:  *null | #stanza.vault
	}

	constraint: {
		attribute: string | *null
		value:     string
		operator:  *"=" | "!=" | ">" | ">=" | "<" | "<=" | "distinct_hosts" | "distinct_property" | "regexp" | "set_contains" | "version" | "semver" | "is_set" | "is_not_set"
	}

	ephemeral_disk: *null | {
		size:    uint & >0
		migrate: bool | *false
		sticky:  bool | *false
	}

	group: {
		ephemeral_disk: #stanza.ephemeral_disk
		network:        #stanza.network
		service: [string]: #stanza.service
		task: [string]:    #stanza.task
		count: uint | *null
		volume: [string]: #stanza.volume
		restart: #stanza.restart & {#type: #type}
		vault:   *null | #stanza.vault
	}

	network: {
		mode: "host" | "bridge"
		port: [string]: {
			static:       *null | uint
			to:           *null | uint
			host_network: *"" | string
		}
	}

	restart: {
		#type: "batch" | *"service" | "system"

		// Specifies the number of restarts allowed in the configured interval.
		attempts: uint

		// Specifies the duration to wait before restarting a task. This is
		// specified using a label suffix like "30s" or "1h". A random jitter of up
		// to 25% is added to the delay.
		delay: durationType | *"15s"

		// Specifies the duration which begins when the first task starts and
		// ensures that only attempts number of restarts happens within it. If more
		// than attempts number of failures happen, behavior is controlled by mode.
		// This is specified using a label suffix like "30s" or "1h".
		interval: durationType

		// Controls the behavior when the task fails more than attempts times in an
		// interval.
		mode: *"fail" | "delay"

		if #type == "batch" {
			attempts: uint | *3
			interval: durationType | *"24h"
		}

		if #type == "service" || #type == "system" {
			attempts: uint | *2
			interval: durationType | *"30m"
		}
	}

	service: {
		check_restart: null
		port:          string
		address_mode:  "host" | "driver" | "alloc"
		tags: [...string]
		task: string
		check: [string]: {
			type:     "http"
			port:     string
			interval: durationType
			path:     string
			timeout:  durationType
			check_restart: {
				limit:           uint
				grace:           durationType
				ignore_warnings: bool | *false
			}
		}
		meta: [string]: string
	}

	config: {
		flake:   string
		command: string
		args: [...string]
	}

	task: {
		artifact: [Destination=_]: {
			destination: Destination
			headers: [string]: string
			mode: *"any" | "file" | "dir"
			options: [string]: string
			source: string
		}

		config: #stanza.config

		driver: "exec" | "docker" | "nspawn"

		env: [string]: string

		kill_signal: string | *"SIGINT"
		if driver == "docker" {
			kill_signal: string | *"SIGTERM"
		}

		resources: {
			cpu:    uint
			memory: uint
		}

		restart: #stanza.restart & {#type: #type}

		template: [Destination=_]: {
			destination:     Destination
			data:            *"" | string
			source:          *"" | string
			env:             bool | *false
			change_mode:     *"restart" | "noop" | "signal"
			change_signal:   *"" | string
			left_delimiter:  string | *"{{"
			right_delimiter: string | *"}}"
		}

		vault: *null | #stanza.vault
		volume_mount: [string]: #stanza.volume_mount
	}

	update: {
		// Specifies the number of allocations within a task group that can be
		// updated at the same time. The task groups themselves are updated in
		// parallel.
		// max_parallel: 0 - Specifies that the allocation should use forced
		// updates instead of deployments
		max_parallel: uint | *1

		// Specifies the mechanism in which allocations health is determined.
		health_check: *"checks" | "task_states" | "manual"

		// Specifies the minimum time the allocation must be in the healthy state
		// before it is marked as healthy and unblocks further allocations from
		// being updated.
		min_healthy_time: durationType | *"10s"

		// Specifies the deadline in which the allocation must be marked as healthy
		// after which the allocation is automatically transitioned to unhealthy.
		// If progress_deadline is non-zero, it must be greater than
		// healthy_deadline.  Otherwise the progress_deadline may fail a deployment
		// before an allocation reaches its healthy_deadline.
		healthy_deadline: durationType | *"5m"

		// Specifies the deadline in which an allocation must be marked as healthy.
		// The deadline begins when the first allocation for the deployment is
		// created and is reset whenever an allocation as part of the deployment
		// transitions to a healthy state. If no allocation transitions to the
		// healthy state before the progress deadline, the deployment is marked as
		// failed. If the progress_deadline is set to 0, the first allocation to be
		// marked as unhealthy causes the deployment to fail.
		progress_deadline: durationType | *"10m"

		// Specifies if the job should auto-revert to the last stable job on
		// deployment failure. A job is marked as stable if all the allocations as
		// part of its deployment were marked healthy.
		auto_revert: bool | *false

		// Specifies if the job should auto-promote to the canary version when all
		// canaries become healthy during a deployment. Defaults to false which
		// means canaries must be manually updated with the nomad deployment
		// promote command.
		auto_promote: bool | *false

		// Specifies that changes to the job that would result in destructive
		// updates should create the specified number of canaries without stopping
		// any previous allocations. Once the operator determines the canaries are
		// healthy, they can be promoted which unblocks a rolling update of the
		// remaining allocations at a rate of max_parallel.
		canary: uint | *0

		// Specifies the delay between each set of max_parallel updates when
		// updating system jobs. This setting no longer applies to service jobs
		// which use deployments.
		stagger: durationType | *"30s"
	}

	vault: {
		change_mode:   "noop" | *"restart" | "signal"
		change_signal: string | *""
		env:           bool | *true
		namespace:     string | *""
		policies: [...string]
	}

	volume: {
		type:      "host" | "csi"
		source:    string
		read_only: bool | *false
		mount_options: {
			fs_type:     *null | string
			mount_flags: *null | string
		}
	}

	volume_mount: {
		// Specifies the group volume that the mount is going to access.
		volume: string | *""

		// Specifies where the volume should be mounted inside the task's
		// allocation.
		destination: string | *""

		// When a group volume is writeable, you may specify that it is read_only
		// on a per mount level using the read_only option here.
		read_only: bool | *false
	}
}
