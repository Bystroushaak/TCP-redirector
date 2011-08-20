import std.stdio;
import std.string;

import std.socket;
import std.socketstream;

///
void printHelp(string pname){
	stderr.writeln(
		"Usage:\n" ~
		pname ~ " L_PORT RHOST:RPORT\n"
	);
}

void tcp_redirector(ushort lport, string rhost, ushort rport){
	
}

void udp_redirector(ushort lport, string rhost, ushort rport){
}

int main(string[] args){
	ushort lport, rport;
	string host;
	
	if (args.length != 3){
		stderr.writeln("Bad number of arguments!\n");
		printHelp(args[0]);
		return 1;
	}
	
	// parse LPORT
	try{
		lport = std.conv.to!(ushort)(args[1]);
	}catch(Exception e){
		stderr.writeln("LPORT must be port number (1 .. 65535), not '" ~ args[1] ~ "'!\n");
		printHelp(args[0]);
		return 1;
	}
	
	// parse RPORT
	try{
		if (args[2].indexOf(":") < 0){
			stderr.writeln("Remote port must be separated from host with ':'!");
			printHelp(args[0]);
			return 1;
		}
		rport = std.conv.to!(ushort)(args[2].split(":")[1]);
	}catch(Exception e){
		stderr.writeln("RPORT must be port number (1 .. 65535), not '" ~ args[2].split(":")[1] ~ "'!\n");
		printHelp(args[0]);
		return 1;
	}
	host = args[2].split(":")[0];
	
	
	
	return 0;
}