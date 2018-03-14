use Test;
use Math::Matrix;
plan 5;


subtest {
    plan 8;
    my $a = Math::Matrix.new( [[1,2,3],[4,5,6]] );
    my $b = Math::Matrix.new( [[7,8],[9,10],[11,12]] );
    my $matrix   = Math::Matrix.new([[1,2],[3,4]]);
    my $identity = Math::Matrix.new-identity(2);

    ok $a.dotProduct( $b ) ~~ Math::Matrix.new([[58,64],[139,154]]), "Simple multiplication check";
    ok ($a ⋅ $b) ~~ Math::Matrix.new([[58,64],[139,154]]),   "Simple multiplication check with ⋅ operator";
    ok ($a dot $b) ~~ Math::Matrix.new([[58,64],[139,154]]), "Simple multiplication check with ⋅ operator, texas form";
    ok $matrix ** 0 ~~ $identity,                             "times one means no multiplication";
    ok $matrix ** 1 ~~ $matrix,                               "times one means no multiplication";
    ok $matrix ** 2 ~~ $matrix dot $matrix,                   "power operator works too";

    my $c = Math::Matrix.new( [[7,8],[9,10],[11,12],[13,14]] );
    dies-ok { $a ⋅ $c } , "Matrices can't be multiplied, first matrix column count should be equal to second matrix row count";
    dies-ok { $a.dotProduct( $c ) } , "Matrices can't be multiplied, first matrix column count should be equal to second matrix row count";
}, "Dot Product";


subtest {
    plan 2;
    my $matrix = Math::Matrix.new([[1,2],[3,4]]);
    my $matrix2 = Math::Matrix.new([[4,3],[2,1]]);
    my $expected = Math::Matrix.new([[5,5],[5,5]]);
    ok $matrix.add( $matrix2 ) ~~ $expected, "Sum of matrices";
    ok $matrix + $matrix2 ~~ $expected, "Sum of matrices using + operator";
}, "Sum of matrices";

subtest {
    plan 2;
    my $matrix = Math::Matrix.new([[1,2],[3,4]]);
    my $matrix2 = Math::Matrix.new([[4,3],[2,1]]);
    my $expected = Math::Matrix.new([[ -3 , -1 ],[ 1 , 3 ]]);
    ok $matrix.subtract( $matrix2 ) ~~ $expected, "Substraction of matrices";
    ok $matrix - $matrix2 ~~ $expected, "Substraction of matrices using - operator";
}, "Substraction of matrices";

subtest {
    plan 2;
    my $matrix = Math::Matrix.new([[1,2],[3,4]]);
    my $matrix2 = Math::Matrix.new([[4,3],[2,1]]);
    my $expected = Math::Matrix.new([[ 4 , 6 ],[ 6 , 4 ]]);
    say $matrix.multiply( $matrix2 );
    ok $matrix.multiply( $matrix2 ) ~~ $expected, "Multiplication of matrices (element by element)";
    ok $matrix * $matrix2 ~~ $expected, "Multiplication of matrices using * operator";
}, "Multiplication of matrices";

subtest {
    plan 3;
    my $matrix = Math::Matrix.new([[1,1],[1,1]]);
    my $expected = Math::Matrix.new([[ 2.2 , 2.2 ],[ 2.2 , 2.2 ]]);
    ok $matrix.multiply( 2.2 ) ~~ $expected, "multiplication with real working";
    ok $matrix * 2.2 ~~ $expected, "multiplication with real working with operator *";
    ok 2.2 * $matrix ~~ $expected, "multiplication with real working with operator *, reverse args";
}, "Multiply Matrix with number";
