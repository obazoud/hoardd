var
	Net = require('net'),
	Fs = require('fs'),
	Path = require('path');

module.exports = function(server) {
	var run,
		metricPrefix = server.fqdn + '.memcached.';

	const stats = 
	[ 'rusage_user', 'rusage_system', 'curr_connections', 'total_connections', 'connection_structures',
		'cmd_get', 'cmd_set', 'cmd_flush', 'get_hits', 'get_misses', 'delete_misses', 'delete_hits',
		'incr_misses', 'incr_hits', 'decr_misses', 'decr_hits', 'cas_misses', 'cas_hits', 'cas_badval',
		'auth_cmds', 'auth_errors', 'bytes_read', 'bytes_written', 'accepting_conns', 'listen_disabled_num',
		'threads', 'conn_yields', 'bytes', 'curr_items', 'total_items', 'evictions', 'reclaimed'
	];

	run = function() {
		var
			confPath = Path.join(server.sPath, 'memcached.json'),
			conf;

		if(Fs.existsSync(confPath)) {
			try {
				conf = JSON.parse(Fs.readFileSync(confPath, 'utf-8'));
			}
			catch(error) {
				return server.cli.fatal('Error reading #{server.sPath}/memcached.json');
			}
		} else {
			return server.cli.fatal('Config file required for memcache.js');
		}

		var buf = '';
		function collect_data(chunk) {
			buf += chunk;

			if(!buf.match(/\nEND\s*$/)) {
				return false;
			}

			server.cli.debug('Memcached stats reply complete');

			var
				lines = buf.split('\n'),
				re = new RegExp('^STAT (' + stats.join('|') + ') ([\\d.]+)\\s*$');

			for(var i in lines) {
				if(lines[i].match(re)) {
					server.push_metric(metricPrefix + RegExp.$1, RegExp.$2);
				}
			}

			buf = '';
			return true;
		}

		server.cli.debug('Running memcached script');

		var socket = Net.connect(conf.port, conf.host);
		socket.on('connect', function() {
			socket.write('stats\r\n');
		}).on('data', function(chunk) {
			chunk = chunk.toString();
			if(chunk.match(/^ERROR/)) {
				server.cli.fatal('Memcached reply was ERROR');
				socket.end();
			} else if(collect_data(chunk)) {
				socket.end();
			}
		}).on('error', function(err) {
			server.cli.debug('memcached.js: ' + err.message);
		});
	}

	return run;
}
