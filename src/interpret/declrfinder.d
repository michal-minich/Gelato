module interpret.declrfinder;

import std.algorithm, std.array, std.conv;
import common, parse.ast, validate.remarks, interpret.preparer, interpret.builtins;



@safe StmDeclr findDeclr (Exp[] exps, dstring name)
{
    foreach (e; exps)
    {
        auto d = cast(StmDeclr)e;
        if (d && d.ident.text == name)
            return d;
    }
    return null;
}

@safe StmDeclr getIdentDeclaredBy (ExpIdent ident)
{
	if (ident.declaredBy)
		return ident.declaredBy;

	auto bfn = ident.text in builtinFns;
	if (bfn)
	{
		auto d = new StmDeclr(null, null);
		d.value = *bfn;
		return d;
	}

	auto d = findIdentDelr (ident, ident.parent);
	if (!d)
	{
		d = new StmDeclr(ident.parent, ident);
		d.value = new AstUnknown(ident);
	}

	return d;
}


@trusted private StmDeclr findIdentDelr (ExpIdent ident, Exp e)
{
	StmDeclr d;
	d = findIdentDelrInExpOrParent(ident.text, e);
	if (d)
		return d;
else
		assert (false, ident.text.to!string() ~ " identifer is undefined");

	/*idents = idents[1 .. $];
	e = d;
	while (e && idents.length)
	{
	d = findIdentDelrInExp(idents[0], e);
	if (d)
	return d;
	idents = idents[1 .. $];
	e = d.value;
	}
	return d;*/
}


private StmDeclr findIdentDelrInExpOrParent (dstring ident, Exp e)
{
	StmDeclr d;
	while (e && !d)
	{
		d = findIdentDelrInExp(ident, e);
		e = e.parent;
	}
	return d;
}


private StmDeclr findIdentDelrInExp (dstring ident, Exp e)
{
	Exp[] exps;
	auto s = cast(ValueFile)e;
	if (s)
		exps = s.exps;

	auto f = cast(ValueStruct)e;
	if (f)
		exps = f.exps;

	if (exps.length)
	{
		foreach (e2; exps)
		{
			auto d = cast(StmDeclr)e2;
			if (d && d.ident.text == ident)
				return d;
		}
		return null;
	}

	auto fn = cast(ValueFn)e;
	if (fn)
	{
		foreach (p; fn.params)
			if (p.ident.text == ident)
				return p;

		foreach (e2; fn.exps)
		{
			if (e2 is e)
				break;
			auto d = cast(StmDeclr)e2;
			if (d && d.ident.text == ident)
				return d;
		}
	}

	return null;
}

