module lru_test;

import std.c.time : time_t;

import lru;
import std.stdio : writefln;

void main() {
	alias SLRU!(string,string) SLRUss;
	auto l = new SLRUss(10);

	void dump() {
	writefln("dump:");
	l.print();
	writefln();
	}

	dump();
	l["michal"] = "ma malgosie";
	dump();
	l["ala"] = "ma kota";
	dump();
	l["jacek"] = "ma asie";
	dump();
	l["ania"] = "ma witka";
	dump();
	l["witek"] = "ma anie";
	dump();
	l["iza"] = "ma piotrka";
	dump();
	l["michal"] = "nie ma malgosie";
	dump();
	l["marek"] = "ma magde";
	dump();
	l["kasia"] = "ma bartka";
	dump();
	l["basia"] = "ma marka";
	dump();


	//writefln("michal ma %s", l["michal"]);
	dump();


	writefln("witek ma %s", l["witek"]);
	dump();
	writefln("witek ma %s", l["witek"]);
	dump();

	writefln("ania ma %s", l["ania"]);
	dump();


	l["ewa"] = "ma janka";
	dump();

	l["janek"] = "ma ewe";
	dump();

	writefln("jacek ma %s", l["jacek"]);
	dump();

	l["janek"] = "ma Ewe";
	dump();

	writefln("jacek ma %s", l["jacek"]);
	dump();

	l["justyna"] = "ma Marcina";
	dump();


	writefln("witek ma %s", l["witek"]);
	dump();
	writefln("witek ma %s", l["witek"]);
	dump();

	l["mm"] = "ma jj";
	dump();

	writefln("witek ma %s", l["witek"]);
	dump();
	writefln("witek ma %s", l["witek"]);
	dump();

}
