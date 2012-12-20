Rest  = require('restler')
Fs    = require 'fs'
Path  = require 'path'

module.exports = (server) ->
  run = () ->
    # This script needs configuration
    confPath     = Path.join server.sPath, 'rabbitmq.json'
    configFile   = Fs.readFileSync confPath, 'utf-8'
    conf         = JSON.parse configFile
    stats = ['ack', 'deliver', 'deliver_get', 'deliver_no_ack', 'publish', 'redeliver', 'return_unroutable']
    queue_totals = ['messages', 'messages_ready', 'messages_unacknowledged']
    nodes = ['mem_ets', 'mem_binary', 'mem_proc', 'mem_proc_used', 'mem_atom', 'mem_atom_used', 'mem_code', 'fd_used', 'fd_total', 'sockets_used', 'sockets_total', 'mem_used', 'mem_limit', 'mem_alarm', 'disk_free_limit', 'disk_free', 'disk_free_alarm', 'proc_used', 'proc_total', 'uptime', 'run_queue', 'processors']
    queues = ['memory', 'consumers']

    send_stat = (stat, data) ->
      try
        server.push_metric "rabbitmq.#{stat}.count", data.message_stats[stat] if data.message_stats[stat]
        server.push_metric "rabbitmq.#{stat}.rate", data.message_stats["#{stat}_details"].rate if data.message_stats["#{stat}_details"]
      catch error
       server.cli.debug error

    send_queue_totals = (queue, data) ->
      try
        server.push_metric "rabbitmq.#{queue}.count", data.queue_totals[queue]
        server.push_metric "rabbitmq.#{queue}.rate", data.queue_totals["#{queue}_details"].rate if data.queue_totals["#{queue}_details"]
      catch error
       server.cli.debug error
      
    send_nodes = (node, data) ->
      try
        server.push_metric "rabbitmq.#{node}", data[0][node]
      catch error
       server.cli.debug error
      
    send_queue = (queue) ->
      try
        server.push_metric "rabbitmq.queue.#{queue.name}.#{q}", queue["#{q}"] for q in queues
        server.push_metric "rabbitmq.queue.#{queue.name}.slave_nodes.count", queue["slave_nodes"].length
        server.push_metric "rabbitmq.queue.#{queue.name}.#{q}.count", queue["#{q}"] for q in queue_totals
        server.push_metric "rabbitmq.queue.#{queue.name}.#{q}.rate", queue["#{q}_details"].rate for q in queue_totals
      catch error
       server.cli.debug error
      
    Rest.get("#{conf.host}:#{conf.port}/api/overview",
      {username: conf.username, password: conf.password}).on 'complete', (data) ->
      rmq_data = eval data
      send_stat stat, rmq_data for stat in stats
      send_queue_totals queue, rmq_data for queue in queue_totals

    Rest.get("#{conf.host}:#{conf.port}/api/nodes",
      {username: conf.username, password: conf.password}).on 'complete', (data) ->
      rmq_data = eval data
      send_nodes node, rmq_data for node in nodes

    Rest.get("#{conf.host}:#{conf.port}/api/queues",
      {username: conf.username, password: conf.password}).on 'complete', (data) ->
      rmq_data = eval data
      send_queue queue for queue in rmq_data
