import mir.bignum.integer: BigInt;
import std.datetime.stopwatch;
import std.bigint: StdBigInt = BigInt;
import std.stdio: writeln;

immutable ps = "E5B5B1EDC8DF0F307C2220151CFCBE31F69B15659A5D6FBA1E50F55A08B341218312D707CFC16ED86A1765F5AEAFA7E6A11C4431038914C76F0F398FE6BE031E289B220D13D9E02226C691D15BC6E1186EA18222D93F52A393BE1DA1A42853512419B5E6E304FD02E962A4C2D0ECDDB8F44AC094FACA8333AE94110A5B10DA539C24A96F08530E7699E3F705165CF14B7F90A2F32ED28D21615F91D7C808AC566D6EEEF6773450AB53542CDAC337C3124530CB16319752267C3422149D41543D8742586BAB578F4E06360745AE0BD8F0E800D1920DC1F3661287367A78967458383A82465C5D966E7299EFCF58BD860185F96655E1F8D300F6B096DFE883CF15";
immutable qs = "D9757338E9A6B363F227F3104EDEF6240C0CAF53B7D509F48870553C4A821F460469AE5616301B9CC30FBF4598A176B84284AF3A41D697A34CDC2C8D88A4C4BE82AE8DB5347511FE5B4DD915CA6A728CCFD0444CE38FC7190824059D86A9083C273581EA5AD1D5E3A8D8EC6858F291A5EADA98B0F5FD7C8E8CA6226657B8B7955796B22899B087714E293A86C78D42A7021754A6220F1D0A9588C280DD9AEC376E421D539F30A3053D95C7D70F24B471D14ECF282FA3E0B1CED2C405BA22404F3B75CD961A46097D7C098324FC47281D298734DA0DFCD8AF82E685657C926672727296147867EAEDFDEF89A79DE81FF104CF7D9157EF65A1BC333C98A7FED685";
immutable es = ps ~ qs;

void stdPowMod(ref StdBigInt base, StdBigInt exponent, StdBigInt modulus)
{
    StdBigInt result = 1;

    while (exponent != 0)
    {
        base %= modulus;
        if (exponent & 1)
        {
            result *= base;
            result %= modulus;
        }
        exponent >>= 1;
        base *= base;
    }
    base = result;
}

void testStd()
{
    StdBigInt p = "0x" ~ ps;
    StdBigInt q = "0x" ~ qs;
    StdBigInt m = p;
    m *= q;
    StdBigInt e = "0x" ~ es;
    StdBigInt b = e;
    b.stdPowMod(e, m);
    // debug writeln(b);
}

void testMir()
{
    auto p = BigInt!64.fromHexString(ps);
    auto q = BigInt!64.fromHexString(qs);
    BigInt!64 m = p;
    m *= q;
    auto e = BigInt!64.fromHexString(es);
    BigInt!64 b = e;
    b.powMod(e, m);
    // debug writeln(b);
}

void main()
{
    auto res = 10.benchmark!(testStd, testMir);
    writeln("std = ", res[0]);
    writeln("mir = ", res[1]);
}
