Program array_errors(input, output);

Var x,y: integer;

  z1: array[9..1] Of integer;
  z2: array[1..9, 2..10] of integer;
  z3: array[-1..9] of integer;
  a: array[adc...10] of integer;
  b: array[] of integer;
  c: array[1..10] of rea;
  d: real;

Function gcd(a,b: integer): integer;

Var f: integer;
Begin
  If b = 0 Then gcd := a
  Else gcd := gcd(b, a Mod b)
End;
Begin
  z2[10, 2.3] := 1;
  z2[1, 2, 3] := 1;
  read(x, y);
  write(gcd(x, y))
End.