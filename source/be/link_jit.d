/**
Copyright: Copyright (c) 2019 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module be.link_jit;

import std.file;
import std.stdio;

import all;

void pass_link_jit(ref CompilationContext context, CompilePassPerModule[] subPasses)
{
	if (context.printSymbols) context.objSymTab.dump(&context);

	context.objSymTab.getSection(context.dataSectionIndex).sectionAddress = cast(ulong)context.staticDataBuffer.bufPtr;
	context.objSymTab.getSection(context.rdataSectionIndex).sectionAddress = cast(ulong)context.roStaticDataBuffer.bufPtr;
	context.objSymTab.getSection(context.importSectionIndex).sectionAddress = cast(ulong)context.importBuffer.bufPtr;
	context.objSymTab.getSection(context.textSectionIndex).sectionAddress = cast(ulong)context.codeBuffer.bufPtr;

	foreach (ref SourceFileInfo file; context.files.data) {
		linkModule(context, file.mod.objectSymIndex);
	}
}
