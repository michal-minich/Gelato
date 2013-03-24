module test.TestFormatVisitor;


import std.conv;
import syntax.ast;


@trusted pure final class TestFormatVisitor : IFormatVisitor
{
    const dstring visit (ValueInt i) { return i.value.to!dstring(); }

    const dstring visit (ValueFloat f) { return f.value.to!dstring(); }

    const dstring visit (ValueUnknown e) { return "ValueUnknown"; }

    const dstring visit (ExpAssign e) { return "ExpAssign"; }

    const dstring visit (ValueStruct e) { return "ValueStruct"; }

    const dstring visit (ValueArray e) { return "ValueArray"; }

    const dstring visit (ValueFn e) { return "ValueFn"; }

    const dstring visit (ExpFnApply e) { return "ExpFnApply"; }

    const dstring visit (ExpIdent i) { return "ExpIdent"; }

    const nothrow dstring visit (StmLabel e) { return "StmLabel"; }

    const dstring visit (StmReturn e) { return "StmReturn"; }

    const dstring visit (StmImport e) { return "StmImport"; }

    const dstring visit (StmThrow) { return "StmThrow"; }

    const dstring visit (ValueText e){ return e.value; }

    const dstring visit (ValueChar e) { return e.value.to!dstring(); }

    const dstring visit (ExpIf e) { return "ExpIf"; }

    const nothrow dstring visit (StmGoto e) { return "StmGoto"; }

    const dstring visit (Closure sc) { return "Closure"; }

    const dstring visit (ExpDot dot) { return "ExpDot"; }

    const dstring visit (TypeType tt) { return "TypeType"; }

    const dstring visit (TypeAny) { return "TypeAny"; }

    const dstring visit (TypeVoid) { return "TypeVoid"; }

    const dstring visit (TypeInt) { return "TypeInt"; }

    const dstring visit (TypeFloat) { return "TypeFloat"; }

    const dstring visit (TypeText) { return "TypeText"; }

    const dstring visit (TypeChar) { return "TypeChar"; }

    const dstring visit (TypeStruct) { return "TypeStruct"; }

    const dstring visit (ValueBuiltinFn) { return "ValueBuiltinFn"; }

    const dstring visit (TypeAnyOf tao) { return "TypeAnyOf"; }

    const dstring visit (TypeArray tao) { return "TypeArray"; }

    const dstring visit (TypeFn tfn) { return "TypeFn"; }

    const dstring visit (WhiteSpace ws) { return "WhiteSpace"; }
}