/// Copyright: Copyright (c) 2017-2020 Andrey Penechko.
/// License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
/// Authors: Andrey Penechko.
module tests.aggregates;

import std.stdio;
import tester;

Test[] aggregatesTests() { return collectTests!(tests.aggregates)(); }


@TestInfo(&tester64)
immutable aggr64 = q{--- aggr64
	// Test structs
	struct Big {
		i64 a;
		i64 b;
	}
	struct Big2
	{
		u8 r;
		u8 g;
		u8 b;
		u8 a;
		u8 r2;
		u8 g2;
		u8 b2;
		u8 a2;
	}
	struct Small {
		i32 a;
		i32 b;
	}
	struct Small3 {
		i32 a;
		i16 b;
		i16 c;
	}
	struct Micro {
		u8 a;
		u8 b;
	}
	struct Mini {
		Micro a;
		Micro b;
	}
	struct Single_u8  { u8  a; }
	struct Single_u16 { u16 a; }
	struct Single_u32 { u32 a; }
	struct Single_u64 { u64 a; }
	// constructor is a function (expression) that returns struct type
	// can compile it into create_aggregate instruction
	// - default initialization of members
	// + return result (by ptr)
	Small returnSmallStruct() {
		return Small(10, 42);
	}
	Single_u8  return_Single_u8_const () { return Single_u8 (42); }
	Single_u16 return_Single_u16_const() { return Single_u16(42); }
	Single_u32 return_Single_u32_const() { return Single_u32(42); }
	Single_u64 return_Single_u64_const() { return Single_u64(42); }

	Single_u8  return_Single_u8 (u8  val) { return Single_u8 (val); }
	Single_u16 return_Single_u16(u16 val) { return Single_u16(val); }
	Single_u32 return_Single_u32(u32 val) { return Single_u32(val); }
	Single_u64 return_Single_u64(u64 val) { return Single_u64(val); }
	// return aggregate by storing into hidden first parameter
	Big returnBigStruct() {
		return Big(10, 42);
	}
	Big returnBigStruct2() {
		Big res = Big(10, 42);
		return res;
	}
	Small buildSmallStruct(i32 a, i32 b) {
		return Small(a, b);
	}
	Small3 buildSmall3Struct(i32 a, i16 b, i16 c) {
		return Small3(a, b, c);
	}
	Mini buildMiniStruct(u8 a, u8 b, u8 c, u8 d) {
		return Mini(Micro(a, b), Micro(c, d));
	}
	Big2 buildBig2Struct(u8 r, u8 g, u8 b, u8 a) {
		return Big2(r, 42, b, 42, 42, g, 42, a);
	}
	Mini returnMiniStruct() {
		return Mini(Micro(10, 42), Micro(120, 3));
	}
	// - pass as arg (fits in register)
	Small passArgSmallStruct() {
		return receiveArgSmallStruct(Small(10, 42));
	}
	// - pass as arg (fits in register, pushed)
	Small passArgSmallStructPush() {
		return receiveArgSmallStructPush(1,2,3,4,Small(10, 42));
	}
	// - pass as arg (by ptr)
	Big passArgBigStruct() {
		return receiveArgBigStruct(Big(10, 42));
	}
	// - pass as arg (by ptr, pushed)
	Big passArgBigStructPush() {
		return receiveArgBigStructPush(1,2,3,4,Big(10, 42));
	}
	// - receive parameter (fits in register)
	Small receiveArgSmallStruct(Small arg) { return arg; }
	Small receiveArgSmallStructPush(i32,i32,i32,i32,Small arg) { return arg; }
	// - receive parameter (by ptr)
	Big receiveArgBigStruct(Big arg) { return arg; }
	Big receiveArgBigStructPush(i32,i32,i32,i32,Big arg) { return arg; }
	// - pass member as arg (by ptr)
	// - pass member as arg (fits in register)
	// - receive result (fits in register)
	// - receive result (by ptr)
	// - return result (fits in register)
	// - store in memory
	// - load from memory
	// - set member
	// - get member
	// - get member ptr
	// - get ptr
};
void tester64(ref TestContext ctx) {
	static struct Big {
		long a;
		long b;
	}
	static struct Big2
	{
		ubyte r;
		ubyte g;
		ubyte b;
		ubyte a;
		ubyte r2;
		ubyte g2;
		ubyte b2;
		ubyte a2;
	}
	static struct Small {
		int a;
		int b;
	}
	static struct Small3 {
		int a;
		short b;
		short c;
	}
	static struct Micro {
		ubyte a;
		ubyte b;
	}
	static struct Mini {
		Micro a;
		Micro b;
	}
	static struct Single_u8  { ubyte  a; }
	static struct Single_u16 { ushort a; }
	static struct Single_u32 { uint   a; }
	static struct Single_u64 { ulong  a; }

	auto returnSmallStruct = ctx.getFunctionPtr!(Small)("returnSmallStruct");
	assert(returnSmallStruct() == Small(10, 42));

	auto return_Single_u8_const = ctx.getFunctionPtr!(Single_u8)("return_Single_u8_const");
	assert(return_Single_u8_const() == Single_u8(42));
	auto return_Single_u16_const = ctx.getFunctionPtr!(Single_u16)("return_Single_u16_const");
	assert(return_Single_u16_const() == Single_u16(42));
	auto return_Single_u32_const = ctx.getFunctionPtr!(Single_u32)("return_Single_u32_const");
	assert(return_Single_u32_const() == Single_u32(42));
	auto return_Single_u64_const = ctx.getFunctionPtr!(Single_u64)("return_Single_u64_const");
	assert(return_Single_u64_const() == Single_u64(42));

	auto return_Single_u8 = ctx.getFunctionPtr!(Single_u8, ubyte)("return_Single_u8");
	assert(return_Single_u8(42) == Single_u8(42));
	auto return_Single_u16 = ctx.getFunctionPtr!(Single_u16, ushort)("return_Single_u16");
	assert(return_Single_u16(42) == Single_u16(42));
	auto return_Single_u32 = ctx.getFunctionPtr!(Single_u32, uint)("return_Single_u32");
	assert(return_Single_u32(42) == Single_u32(42));
	auto return_Single_u64 = ctx.getFunctionPtr!(Single_u64, ulong)("return_Single_u64");
	assert(return_Single_u64(42) == Single_u64(42));

	auto returnBigStruct = ctx.getFunctionPtr!(Big)("returnBigStruct");
	assert(returnBigStruct() == Big(10, 42));

	auto returnBigStruct2 = ctx.getFunctionPtr!(Big)("returnBigStruct2");
	assert(returnBigStruct2() == Big(10, 42));

	auto passArgBigStruct = ctx.getFunctionPtr!(Big)("passArgBigStruct");
	assert(passArgBigStruct() == Big(10, 42));

	auto passArgBigStructPush = ctx.getFunctionPtr!(Big)("passArgBigStructPush");
	assert(passArgBigStructPush() == Big(10, 42));

	auto passArgSmallStruct = ctx.getFunctionPtr!(Small)("passArgSmallStruct");
	assert(passArgSmallStruct() == Small(10, 42));

	auto passArgSmallStructPush = ctx.getFunctionPtr!(Small)("passArgSmallStructPush");
	assert(passArgSmallStructPush() == Small(10, 42));

	auto buildSmallStruct = ctx.getFunctionPtr!(Small, int, int)("buildSmallStruct");
	assert(buildSmallStruct(10, 42) == Small(10, 42));

	auto buildSmall3Struct = ctx.getFunctionPtr!(Small3, int, short, short)("buildSmall3Struct");
	assert(buildSmall3Struct(10, 42, 120) == Small3(10, 42, 120));

	auto buildMiniStruct = ctx.getFunctionPtr!(Mini, ubyte, ubyte, ubyte, ubyte)("buildMiniStruct");
	assert(buildMiniStruct(10, 42, 120, 3) == Mini(Micro(10, 42), Micro(120, 3)));

	auto buildBig2Struct = ctx.getFunctionPtr!(Big2, ubyte, ubyte, ubyte, ubyte)("buildBig2Struct");
	assert(buildBig2Struct(10, 42, 120, 3) == Big2(10, 42, 120, 42, 42, 42, 42, 3));

	auto returnMiniStruct = ctx.getFunctionPtr!(Mini)("returnMiniStruct");
	assert(returnMiniStruct() == Mini(Micro(10, 42), Micro(120, 3)));
}


@TestInfo(&tester129)
immutable aggr129 = q{--- aggr129
	// Extract member from small struct (0 offset)
	struct Point { i32 x; i32 y; }
	void run(Point* points, Point neighbor)
	{
		Point* t = &points[neighbor.x]; // neighbor.x is 0th member
		t.x = 42;
	}
};
void tester129(ref TestContext ctx) {
	static struct Point { int x; int y; }
	auto run = ctx.getFunctionPtr!(void, Point*, Point)("run");
	Point point;
	run(&point, Point(0, 0));
	assert(point == Point(42, 0));
}


@TestInfo(&tester130)
immutable aggr130 = q{--- aggr130
	// Extract member from small struct (1 offset)
	struct Point { i32 x; i32 y; }
	void run(Point* points, Point neighbor)
	{
		Point* t = &points[neighbor.y]; // neighbor.y is 1st member
		t.y = 42;
	}
};
void tester130(ref TestContext ctx) {
	static struct Point { int x; int y; }
	auto run = ctx.getFunctionPtr!(void, Point*, Point)("run");
	Point point;
	run(&point, Point(0, 0));
	assert(point == Point(0, 42));
}


@TestInfo(&tester131)
immutable aggr131 = q{--- aggr131
	// Construct and store into ptr
	struct Point { i32 x; i32 y; }
	void run(Point* point, i32 x, i32 y)
	{
		*point = Point(x, y);
	}
};
void tester131(ref TestContext ctx) {
	static struct Point { int x; int y; }
	auto run = ctx.getFunctionPtr!(void, Point*, int, int)("run");
	Point point;
	run(&point, 42, 90);
	assert(point == Point(42, 90));
}
