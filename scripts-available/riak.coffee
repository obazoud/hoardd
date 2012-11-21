# Explanation of stats: http://wiki.basho.com/HTTP-Status.html
http = require 'http'
Fs    = require 'fs'
Path  = require 'path'

module.exports = (server) ->
  run = () ->
    # This script needs configuration
    if Fs.existsSync
      confPath     = Path.join server.sPath, 'riak.json'
      try
        conf         = JSON.parse(Fs.readFileSync(confPath, 'utf-8'))
      catch error
        server.cli.debug "Error reading #{server.sPath}/riak.json"
    else
      server.cli.fatal "Config file required for riak.coffee"
    
    # TODO - move me to a config file
    options = {
      host: conf.host,
      port: conf.port,
      path: conf.path,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    # Counters not being logged because they are last 60 second counters.
    # Totals are being logged and last 60 seconds can be derived from them
    # vnode_gets vnode_puts vnode_index_reads vnode_index_writes 
    # vnode_index_deletes read_repairs node_gets node_puts pbc_connects
    #
    #
    stats = ['handoff_timeouts', 'sys_process_count', 'pbc_connects_total', 
    'pbc_active', 'memory_total', 'memory_processes', 'memory_processes_used', 
    'memory_system', 'memory_atom', 'memory_atom_used', 'memory_binary', 
    'memory_code', 'memory_ets', 'ignored_gossip_total', 'node_puts_total', 
    'vnode_gets_total', 'vnode_puts_total', 'vnode_index_reads_total', 
    'vnode_index_writes_total', 'vnode_index_writes_postings_total', 
    'vnode_index_deletes_total', 'vnode_index_deletes_postings_total', 
    'read_repairs_total', 'coord_redirs_total', 'precommit_fail', 
    'postcommit_fail', 'mem_total', 'mem_allocated', 'sys_global_heaps_size', 
    'node_gets_total' ]
    # Stats for the last 60 seconds.  Broken out to make it easy to change graphite aggregation
    stats60sec = ['node_get_fsm_time_mean', 'node_get_fsm_time_median', 
    'node_get_fsm_time_95', 'node_get_fsm_time_99', 'node_get_fsm_time_100', 
    'node_put_fsm_time_mean', 'node_put_fsm_time_median', 'node_put_fsm_time_95', 
    'node_put_fsm_time_99', 'node_put_fsm_time_100', 'node_get_fsm_siblings_mean', 
    'node_get_fsm_siblings_median', 'node_get_fsm_siblings_95', 
    'node_get_fsm_siblings_99', 'node_get_fsm_siblings_100', 
    'node_get_fsm_objsize_mean', 'node_get_fsm_objsize_median', 
    'node_get_fsm_objsize_95', 'node_get_fsm_objsize_99', 'node_get_fsm_objsize_100' ]
    
    send_stat = (stat, data) ->
      try
        server.push_metric "#{server.fqdn}.#{stat}", data[stat], "riak"
      catch error
       server.cli.debug error
       
    send_nodes = (data) ->
      try
        server.push_metric "#{server.fqdn}.connected_nodes", data['connected_nodes'].length, "riak"
        server.push_metric "#{server.fqdn}.ring_members", data['ring_members'].length, "riak"
      catch error
        server.cli.debug error

      # Why does riak not give us valid JSON for ring_ownership?
      # Original line: "ring_ownership": "[{'riak@.node1',44},\n {'riak@node2',42},\n {'riak@node3',42}]",
      # Nasty regexes to format this to split it into an array.
      # I'm sure there is a much more efficient way to do this, but the big hammer works
      ring_ownership = data['ring_ownership'].replace /',/g, "':"
      ring_ownership = ring_ownership.replace /riak@/g, ""
      ring_ownership = ring_ownership.replace /\./g, "_"
      ring_ownership = ring_ownership.replace /[\{\}\[\]\s\']/g, ""
      ring_ownership = ring_ownership.split ','

      for node in ring_ownership
        info = node.split ':'
        try
          server.push_metric "#{server.fqdn}.ring_ownership.#{info[0]}", info[1], "riak"
        catch error
          server.cli.debug error

    http.get options, (response) ->
      body = ''
      response.on 'data', (chunk) ->
        body += chunk
      response.on 'end', () ->
        # this used to blow up sometimes b/c of incomplete json data - think it is resolved
        try
          riak_data = JSON.parse(body)
          send_stat stat, riak_data for stat in stats
          send_stat stat, riak_data for stat in stats60sec
          send_nodes riak_data
        catch error
          server.cli.debug error
          server.cli.debug '' + response

