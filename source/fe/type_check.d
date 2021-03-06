/**
Copyright: Copyright (c) 2017-2019 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module fe.type_check;

import std.stdio;
import std.string : format;
import all;

void pass_type_check(ref CompilationContext context, CompilePassPerModule[] subPasses)
{
	auto state = TypeCheckState(&context);

	foreach (ref SourceFileInfo file; context.files.data) {
		AstIndex modIndex = file.mod.get_ast_index(&context);
		require_type_check(modIndex, state);
		assert(context.analisysStack.length == 0);

		if (context.printAstSema && modIndex) {
			writefln("// AST typed `%s`", file.name);
			print_ast(context.getAstNodeIndex(file.mod), &context, 2);
		}
	}
}

struct TypeCheckState
{
	CompilationContext* context;
	FunctionDeclNode* curFunc;
	AstIndex parentType;
}

/// Type checking for static context
void require_type_check(ref AstIndex nodeIndex, CompilationContext* context)
{
	auto state = TypeCheckState(context);
	require_type_check(nodeIndex, state);
}

void require_type_check(ref AstNodes items, ref TypeCheckState state)
{
	foreach(ref AstIndex item; items) require_type_check(item, state);
}

/// Annotates all expression nodes with their type
/// Type checking, casting
void require_type_check(ref AstIndex nodeIndex, ref TypeCheckState state)
{
	AstNode* node = state.context.getAstNode(nodeIndex);
	//writefln("require_type_check %s %s", node.astType, node.state);

	switch(node.state) with(AstNodeState)
	{
		case name_register_self, name_register_nested, name_resolve, type_check:
			state.context.circular_dependency; return;
		case parse_done:
			auto name_state = NameRegisterState(state.context);
			require_name_register_self(0, nodeIndex, name_state);
			state.context.throwOnErrors;
			goto case;
		case name_register_self_done:
			auto name_state = NameRegisterState(state.context);
			require_name_register(nodeIndex, name_state);
			state.context.throwOnErrors;
			goto case;
		case name_register_nested_done:
			require_name_resolve(nodeIndex, state.context);
			state.context.throwOnErrors;
			break;
		case name_resolve_done: break; // all requirement are done
		case type_check_done, ir_gen_done: return; // already type checked
		default: state.context.internal_error(node.loc, "Node %s in %s state", node.astType, node.state);
	}

	final switch(node.astType) with(AstType)
	{
		case error: state.context.internal_error(node.loc, "Visiting error node"); break;
		case abstract_node: state.context.internal_error(node.loc, "Visiting abstract node"); break;

		case decl_alias: type_check_alias(cast(AliasDeclNode*)node, state); break;
		case decl_alias_array: assert(false);
		case decl_builtin: assert(false);
		case decl_module: type_check_module(cast(ModuleDeclNode*)node, state); break;
		case decl_import: assert(false);
		case decl_function: type_check_func(cast(FunctionDeclNode*)node, state); break;
		case decl_var: type_check_var(cast(VariableDeclNode*)node, state); break;
		case decl_struct: type_check_struct(cast(StructDeclNode*)node, state); break;
		case decl_enum: type_check_enum(cast(EnumDeclaration*)node, state); break;
		case decl_enum_member: type_check_enum_member(cast(EnumMemberDecl*)node, state); break;
		case decl_static_assert: type_check_static_assert(cast(StaticAssertDeclNode*)node, state); break;
		case decl_static_foreach: assert(false);
		case decl_static_if: assert(false);
		case decl_template: assert(false);
		case decl_template_param: assert(false);

		case stmt_block: type_check_block(cast(BlockStmtNode*)node, state); break;
		case stmt_if: type_check_if(cast(IfStmtNode*)node, state); break;
		case stmt_while: type_check_while(cast(WhileStmtNode*)node, state); break;
		case stmt_do_while: type_check_do(cast(DoWhileStmtNode*)node, state); break;
		case stmt_for: type_check_for(cast(ForStmtNode*)node, state); break;
		case stmt_switch: type_check_switch(cast(SwitchStmtNode*)node, state); break;
		case stmt_return: type_check_return(cast(ReturnStmtNode*)node, state); break;
		case stmt_break: assert(false);
		case stmt_continue: assert(false);

		case expr_name_use: type_check_name_use(nodeIndex, cast(NameUseExprNode*)node, state); break;
		case expr_member: type_check_member(nodeIndex, cast(MemberExprNode*)node, state); break;
		case expr_bin_op: type_check_binary_op(cast(BinaryExprNode*)node, state); break;
		case expr_un_op: type_check_unary_op(cast(UnaryExprNode*)node, state); break;
		case expr_call: type_check_call(nodeIndex, cast(CallExprNode*)node, state); break;
		case expr_index: type_check_index(nodeIndex, cast(IndexExprNode*)node, state); break;
		case expr_slice: type_check_expr_slice(cast(SliceExprNode*)node, state); break;
		case expr_type_conv: type_check_type_conv(cast(TypeConvExprNode*)node, state); break;

		case literal_int: type_check_literal_int(cast(IntLiteralExprNode*)node, state); break;
		case literal_string: type_check_literal_string(cast(StringLiteralExprNode*)node, state); break;
		case literal_null: type_check_literal_null(cast(NullLiteralExprNode*)node, state); break;
		case literal_bool: type_check_literal_bool(cast(BoolLiteralExprNode*)node, state); break;
		case literal_array: type_check_literal_array(cast(ArrayLiteralExprNode*)node, state); break;

		case type_basic: assert(false);
		case type_func_sig: type_check_func_sig(cast(FunctionSignatureNode*)node, state); break;
		case type_ptr: type_check_ptr(cast(PtrTypeNode*)node, state); break;
		case type_static_array: type_check_static_array(cast(StaticArrayTypeNode*)node, state); break;
		case type_slice: type_check_slice(cast(SliceTypeNode*)node, state); break;
	}
}

void require_type_check_expr(AstIndex targetType, ref AstIndex nodeIndex, ref TypeCheckState state)
{
	auto temp = state.parentType;
	state.parentType = targetType;
	require_type_check(nodeIndex, state);
	state.parentType = temp;
}

// Returns error if no common type can be found
AstIndex calcCommonType(AstIndex a, AstIndex b, CompilationContext* c)
{
	TypeNode* typeA = a.get_type(c);
	TypeNode* typeB = b.get_type(c);

	if (typeA.isTypeBasic && typeB.isTypeBasic) {
		BasicType commonType = commonBasicType[typeA.as_basic.basicType][typeB.as_basic.basicType];
		return c.basicTypeNodes(commonType);
	} else if (typeA.isPointer && typeB.isTypeofNull) {
		return a;
	} else if (typeA.isTypeofNull && typeB.isPointer) {
		return b;
	}
	return CommonAstNodes.type_error;
}

/// Returns true if types are equal or were converted to common type. False otherwise
bool autoconvToCommonType(ref AstIndex leftIndex, ref AstIndex rightIndex, CompilationContext* c)
{
	AstNode* leftNode = leftIndex.get_node(c);
	AstNode* rightNode = rightIndex.get_node(c);

	if (leftNode.isType || rightNode.isType)
	{
		TypeNode* leftType = leftIndex.get_expr_type(c).get_type(c);
		TypeNode* rightType = rightIndex.get_expr_type(c).get_type(c);
		if (leftType.isTypeBasic && rightType.isTypeBasic) {
			BasicType commonType = commonBasicType[leftType.as_basic.basicType][rightType.as_basic.basicType];
			if (commonType == BasicType.t_error) return false;

			AstIndex type = c.basicTypeNodes(commonType);
			bool successLeft = autoconvTo(leftIndex, type, c);
			bool successRight = autoconvTo(rightIndex, type, c);
			if(successLeft && successRight)
				return true;
		}
	}

	ExpressionNode* left = leftIndex.get_expr(c);
	ExpressionNode* right = rightIndex.get_expr(c);
	TypeNode* leftType = left.type.get_type(c);
	TypeNode* rightType = right.type.get_type(c);

	if (leftType.isTypeBasic && rightType.isTypeBasic)
	{
		BasicType commonType = commonBasicType[leftType.as_basic.basicType][rightType.as_basic.basicType];
		if (commonType == BasicType.t_error) return false;

		AstIndex type = c.basicTypeNodes(commonType);
		bool successLeft = autoconvTo(leftIndex, type, c);
		bool successRight = autoconvTo(rightIndex, type, c);
		if(successLeft && successRight)
			return true;
	}
	else if (leftType.isPointer && rightType.isTypeofNull) {
		right.type = left.type;
		return true;
	}
	else if (leftType.isTypeofNull && rightType.isPointer) {
		left.type = right.type;
		return true;
	}
	else
	{
		// error for user-defined types
	}

	return false;
}

void autoconvToBool(ref AstIndex exprIndex, CompilationContext* context)
{
	ExpressionNode* expr = exprIndex.get_expr(context);
	if (expr.type.get_type(context).isError) return;
	if (!autoconvTo(exprIndex, context.basicTypeNodes(BasicType.t_bool), context))
		context.error(expr.loc, "Cannot implicitly convert `%s` to bool",
			expr.type.typeName(context));
}

bool isConvertibleTo(AstIndex fromTypeIndex, AstIndex toTypeIndex, CompilationContext* context)
{
	TypeNode* fromType = fromTypeIndex.get_type(context);
	TypeNode* toType = toTypeIndex.get_type(context);

	if (same_type(fromTypeIndex, toTypeIndex, context)) return true;

	if (fromType.astType == AstType.type_basic && toType.astType == AstType.type_basic)
	{
		BasicType fromTypeBasic = fromType.as_basic.basicType;
		BasicType toTypeBasic = toType.as_basic.basicType;
		bool isRegisterTypeFrom =
			(fromTypeBasic >= BasicType.t_bool &&
			fromTypeBasic <= BasicType.t_u64);
		bool isRegisterTypeTo =
			(toTypeBasic >= BasicType.t_bool &&
			toTypeBasic <= BasicType.t_u64);
		// all integer types, pointers and bool can be converted between
		// TODO: bool is special (need to have 0 or 1)
		return isRegisterTypeFrom && isRegisterTypeTo;
	}
	if (fromType.isPointer && toType.isPointer) return true;
	if (fromType.isPointer && toType.isInteger) return true;
	if (fromType.isInteger && toType.isPointer) return true;
	return false;
}

/// Returns true if conversion was successful. False otherwise
bool autoconvTo(ref AstIndex exprIndex, AstIndex typeIndex, CompilationContext* context)
{
	CompilationContext* c = context;

	AstNode* exprNode = exprIndex.get_node(c);
	TypeNode* type = typeIndex.get_type(c);

	if (exprNode.isType)
	{
		if (type.astType == AstType.type_basic)
		{
			auto basicType = type.as_basic.basicType;
			if (basicType == BasicType.t_alias || basicType == BasicType.t_type) {
				exprIndex = c.appendAst!TypeConvExprNode(exprNode.loc, typeIndex, exprIndex);
				exprIndex.setState(c, AstNodeState.type_check_done);
				return true;
			}
		}
		return false;
	}

	ExpressionNode* expr = exprIndex.get_expr(c);

	if (type.isError) { // Recover
		expr.type = c.basicTypeNodes(BasicType.t_error);
		return true;
	}

	TypeNode* exprType = expr.type.get_type(c);

	if (exprType.isError) { // Recover
		expr.type = typeIndex;
		return true;
	}

	if (same_type(expr.type, typeIndex, c)) return true;

	if (exprType.astType == AstType.type_basic && type.astType == AstType.type_basic)
	{
		BasicType fromType = exprType.as_basic.basicType;
		BasicType toType = type.as_basic.basicType;
		bool canConvert = isAutoConvertibleFromToBasic[fromType][toType];
		if (canConvert)
		{
			if (expr.astType == AstType.literal_int) {
				//writefln("int %s %s -> %s", expr.loc, expr.type.printer(c), type.printer(c));
				// change type of int literal inline
				expr.type = typeIndex;
			} else {
				exprIndex = c.appendAst!TypeConvExprNode(expr.loc, typeIndex, exprIndex);
				exprIndex.setState(c, AstNodeState.type_check_done);
			}
			return true;
		}
		else if (expr.astType == AstType.literal_int && toType.isInteger) {
			auto lit = cast(IntLiteralExprNode*) expr;
			if (lit.isSigned) {
				if (numSignedBytesForInt(lit.value) <= integerSize(toType)) {
					expr.type = typeIndex;
					return true;
				}
			} else {
				if (numUnsignedBytesForInt(lit.value) <= integerSize(toType)) {
					expr.type = typeIndex;
					return true;
				}
			}

			c.error(expr.loc, "Cannot auto-convert integer `0x%X` of type %s to `%s`",
				lit.value,
				expr.type.printer(c),
				type.printer(c));
			return false;
		}
	}
	// auto cast from string literal to c_char*
	else if (expr.astType == AstType.literal_string)
	{
		if (type.astType == AstType.type_ptr)
		{
			TypeNode* ptrBaseType = type.as_ptr.base.get_type(c);
			if (ptrBaseType.astType == AstType.type_basic &&
				ptrBaseType.as_basic.basicType == BasicType.t_u8)
			{
				AstIndex parentScope; // no scope
				auto memberExpr = c.appendAst!MemberExprNode(expr.loc, parentScope, exprIndex, Identifier(), typeIndex);
				auto node = memberExpr.get!MemberExprNode(c);
				node.resolve(MemberSubType.slice_member, c.builtinNodes(BuiltinId.slice_ptr), 1, c);
				node.state = AstNodeState.type_check;
				exprIndex = memberExpr;
				return true;
			}
		}
	}
	else if (exprType.isStaticArray && type.isSlice)
	{
		if (same_type(exprType.as_static_array.base, type.as_slice.base, c))
		{
			exprIndex = c.appendAst!UnaryExprNode(
				expr.loc, typeIndex, UnOp.staticArrayToSlice, exprIndex);
			return true;
		}
	}
	else if (expr.astType == AstType.literal_null) {
		if (type.isPointer) {
			expr.type = typeIndex;
			return true;
		} else if (type.isSlice) {
			expr.type = typeIndex;
			return true;
		}
	}
	else if (exprType.astType == AstType.type_func_sig && type.isAlias)
	{
		exprIndex = c.appendAst!TypeConvExprNode(expr.loc, typeIndex, exprIndex);
		exprIndex.setState(c, AstNodeState.type_check_done);
		return true;
	}

	return false;
}
