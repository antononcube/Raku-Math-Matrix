use v6.c;
need Math::Matrix::Operators;

unit class Math::Matrix:ver<0.1.8>:auth<github:pierre-vigier> does Math::Matrix::Operators;
use AttrX::Lazy;

has @!rows is required;
has $!diagonal is lazy;

has Int $!row-count;
has Int $!column-count;

has Bool $!is-zero is lazy;
has Bool $!is-identity is lazy;
has Bool $!is-diagonal is lazy;
has Bool $!is-lower-triangular is lazy;
has Bool $!is-upper-triangular is lazy;
has Bool $!is-square is lazy;
has Bool $!is-symmetric is lazy;
has Bool $!is-self-adjoint is lazy;
has Bool $!is-unitary is lazy;
has Bool $!is-orthogonal is lazy;
has Bool $!is-invertible is lazy;
has Bool $!is-positive-definite is lazy;
has Bool $!is-positive-semidefinite is lazy;

has Numeric $!trace is lazy;
has Numeric $!determinant is lazy;
has Rat $!density is lazy;
has Int $!rank is lazy;
has Int $!kernel is lazy;

method !rows       { @!rows }
method !clone_rows  { AoA_clone(@!rows) }
method !row-count    { $!row-count }
method !column-count  { $!column-count }

subset Positive_Int of Int where * > 0 ;

################################################################################
# start constructors
################################################################################

method new( @m ) {
    die "Expect an Array of Array" unless all @m ~~ Array;
    die "All Row must contains the same number of elements" unless @m[0] == all @m[*];
    die "All Row must contains only numeric values" unless all( @m[*;*] ) ~~ Numeric;
    self.bless( rows => @m );
}

method clone { self.bless( rows => @!rows ) }

sub AoA_clone (@m)  {  map {[ map {$^cell.clone}, $^row.flat ]}, @m }

submethod BUILD( :@rows!, :$diagonal, :$density, :$trace, :$determinant, :$rank, :$kernel,
                 :$is-zero, :$is-identity, :$is-symmetric, :$is-upper-triangular, :$is-lower-triangular ) {
    @!rows = AoA_clone (@rows);
    $!row-count = @rows.elems;
    $!column-count = @rows[0].elems;
    $!diagonal = $diagonal if $diagonal.defined;
    $!density  = $density if $density.defined;
    $!trace    = $trace if $trace.defined;
    $!determinant = $determinant if $determinant.defined;
    $!rank   = $rank if $rank.defined;
    $!kernel = $kernel if $kernel.defined;
    $!is-zero = $is-zero if $is-zero.defined;
    $!is-identity = $is-identity if $is-identity.defined;
    $!is-symmetric = $is-symmetric if $is-symmetric.defined;
    $!is-upper-triangular = $is-upper-triangular if $is-upper-triangular.defined;
    $!is-lower-triangular = $is-lower-triangular if $is-lower-triangular.defined;
}

method !zero_array( Positive_Int $rows, Positive_Int $cols = $rows ) {
    return [ [ 0 xx $cols ] xx $rows ];
}
multi method new-zero(Math::Matrix:U: Positive_Int $size) {
    self.bless( rows => self!zero_array($size, $size),
            determinant => 0, rank => 0, kernel => $size, density => 0.0, trace => 0,
            is-zero => True, is-identity => False, is-diagonal => True, 
            is-square => True, is-symmetric => True  );
}
multi method new-zero(Math::Matrix:U: Positive_Int $rows, Positive_Int $cols) {
    self.bless( rows => self!zero_array($rows, $cols),
            determinant => 0, rank => 0, kernel => min($rows, $cols), density => 0.0, trace => 0,
            is-zero => True, is-identity => False, is-diagonal => ($cols == $rows),  );
}

method !identity_array( Positive_Int $size ) {
    my @identity;
    for ^$size X ^$size -> ($r, $c) { @identity[$r][$c] = ($r == $c ?? 1 !! 0) }
    return @identity;
}

method new-identity(Math::Matrix:U: Positive_Int $size ) {
    self.bless( rows => self!identity_array($size), diagonal => (1) xx $size, 
                determinant => 1, rank => $size, kernel => 0, density => 1/$size, trace => $size,
                is-zero => False, is-identity => True, 
                is-square => True, is-diagonal => True, is-symmetric => True );
}

method new-diagonal(Math::Matrix:U: *@diag ){
    fail "Expect an List of Number" unless @diag and [and] @diag >>~~>> Numeric;
    my Int $size = +@diag;
    my @d = self!zero_array($size, $size);
    (^$size).map: { @d[$_][$_] = @diag[$_] };

    self.bless( rows => @d, diagonal => @diag,
                determinant => [*](@diag.flat), trace => [+] (@diag.flat),
                is-square => True, is-diagonal => True, is-symmetric => True  );
}

method !new-lower-triangular(Math::Matrix:U: @m ) {
    #don't want to trust outside of the class that a matrix is really triangular
    self.bless( rows => @m, is-lower-triangular => True );
}

method !new-upper-triangular(Math::Matrix:U: @m ) {
    #don't want to trust outside of the class that a matrix is really triangular
    self.bless( rows => @m, is-upper-triangular => True );
}

method new-vector-product (Math::Matrix:U: @column_vector, @row_vector ){
    fail "Expect two Lists of Number" unless [and](@column_vector >>~~>> Numeric) and [and](@row_vector >>~~>> Numeric);
    my @p;
    for ^+@column_vector X ^+@row_vector -> ($r, $c) { 
        @p[$r][$c] = @column_vector[$r] * @row_vector[$c] 
    }
    self.bless( rows => @p, determinant => 0 , rank => 1 );
}

################################################################################
# end of constructor - start accessors
################################################################################

method cell(Math::Matrix:D: Int:D $row, Int:D $column --> Numeric ) {
    fail X::OutOfRange.new(
        :what<Row index> , :got($row), :range("0..{$!row-count -1 }")
    ) unless 0 <= $row < $!row-count;
    fail X::OutOfRange.new(
        :what<Column index> , :got($column), :range("0..{$!column-count -1 }")
    ) unless 0 <= $column < $!column-count;
    return @!rows[$row][$column];
}

method row(Math::Matrix:D: Int:D $row  --> List) {
    fail X::OutOfRange.new(
        :what<Row index> , :got($row), :range("0..{$!row-count -1 }")
    ) unless 0 <= $row < $!row-count;
    return @!rows[$row].list;
}

method column(Math::Matrix:D: Int:D $column --> List) {
    fail X::OutOfRange.new(
        :what<Column index> , :got($column), :range("0..{$!column-count -1 }")
    ) unless 0 <= $column < $!column-count;
    (@!rows.keys.map:{ @!rows[$_;$column] }).list;
}

method !build_diagonal(Math::Matrix:D: --> List){
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    ( gather for ^$!row-count -> $i { take @!rows[$i;$i] } ).list;
}


multi method submatrix(Math::Matrix:D: Int:D $row, Int:D $col --> Math::Matrix:D ){
    fail X::OutOfRange.new(
        :what<Row index> , :got($row), :range("0..{$!row-count -1 }")
    ) unless 0 <= $row < $!row-count;
    fail X::OutOfRange.new(
        :what<Column index> , :got($col), :range("0..{$!column-count -1 }")
    ) unless 0 <= $col < $!column-count;
    my @rows = ^$!row-count;     @rows.splice($row,1);
    my @cols = ^$!column-count;  @cols.splice($col,1);
    self.submatrix(@rows ,@cols);
}

multi method submatrix(Math::Matrix:D: Int:D $row-min, Int:D $col-min, Int:D $row-max, Int:D $col-max --> Math::Matrix:D ){
    fail "Minimum row has to be smaller than maximum row" if $row-min > $row-max;
    fail "Minimum column has to be smaller than maximum column" if $col-min > $col-max;
    self.submatrix(($row-min .. $row-max).list, ($col-min .. $col-max).list);
}

multi method submatrix(Math::Matrix:D: @rows where .all ~~ Int, @cols where .all ~~ Int --> Math::Matrix:D ){
    fail X::OutOfRange.new(
        :what<Row index> , :got(@rows), :range("0..{$!row-count -1 }")
    ) unless 0 <= all(@rows) < $!row-count;
    fail X::OutOfRange.new(
        :what<Column index> , :got(@cols), :range("0..{$!column-count -1 }")
    ) unless 0 <= all(@cols) < $!column-count;
    Math::Matrix.new([ @rows.map( { [ @!rows[$_][|@cols] ] } ) ]);
}

################################################################################
# end of accessors - start with type conversion and handy shortcuts
################################################################################

method Bool(Math::Matrix:D: --> Bool)    {   ! self.is-zero   }

method Numeric (Math::Matrix:D: --> Int) {   self.elems    }

method Str(Math::Matrix:D: --> Str)      {   @!rows.gist   }

multi method perl(Math::Matrix:D: --> Str) {
  self.WHAT.perl ~ ".new(" ~ @!rows.perl ~ ")";
}

method list-rows(Math::Matrix:D: --> List) {
    (@!rows.map: {$_.flat}).list;
}

method list-columns(Math::Matrix:D: --> List) {
    ((0 .. $!column-count - 1).map: {self.column($_)}).list;
}

method gist(Math::Matrix:D: --> Str) {
    my $max-rows = 20;
    my $max-chars = 80;
    my $max-nr-char = max( @!rows[*;*] ).Int.chars;  # maximal pre digit char in cell
    my $cell_with;
    my $fmt;
    if all( @!rows[*;*] ) ~~ Int {
        $fmt = " %{$max-nr-char}d ";
        $cell_with = $max-nr-char + 2;
    } else {
        my $max-decimal = max( @!rows[*;*].map( { ( .split(/\./)[1] // '' ).chars } ) );
        $max-decimal = 5 if $max-decimal > 5; #more than that is not readable
        $max-nr-char += $max-decimal + 1;
        $fmt = " \%{$max-nr-char}.{$max-decimal}f ";
        $cell_with = $max-nr-char + 3 + $max-decimal;
    }
    my $rows = min $!row-count, $max-rows;
    my $cols = min $!column-count, $max-chars div $cell_with;
    my $row-addon = $!column-count > $cols ?? '..' !! '';
    my $str;
    for @!rows[0 .. $rows-1] -> $r {
        $str ~= ( [~] $r.[0..$cols-1].map( { $_.fmt($fmt) } ) ) ~ "$row-addon\n";
    }
    $str ~= " ...\n" if $!row-count > $max-rows;
    $str.chomp;
}

method full (Math::Matrix:D: --> Str) {
    my $max-char = max( @!rows[*;*] ).Int.chars;
    my $fmt;
    if all( @!rows[*;*] ) ~~ Int {
        $fmt = " %{$max-char}d ";
    } else {
        my $max-decimal = max( @!rows[*;*].map( { ( .split(/\./)[1] // '' ).chars } ) );
        $max-decimal = 5 if $max-decimal > 5; #more than that is not readable
        $max-char += $max-decimal + 1;
        $fmt = " \%{$max-char}.{$max-decimal}f ";
    }
    my $str;
    for @!rows -> $r {
        $str ~= ( [~] $r.map( { $_.fmt($fmt) } ) ) ~ "\n";
    }
    $str;
}

sub insert ($x, @xs) { ([flat @xs[0 ..^ $_], $x, @xs[$_ .. *]] for 0 .. @xs) }
sub order ($sg, @xs) { $sg > 0 ?? @xs !! @xs.reverse }

multi σ_permutations ([]) { [] => 1 }
multi σ_permutations ([$x, *@xs]) {
    σ_permutations(@xs).map({ |order($_.value, insert($x, $_.key)) }) Z=> |(1,-1) xx *
}

################################################################################
# end of type conversion and handy shortcuts - start boolean matrix properties
################################################################################


method equal(Math::Matrix:D: Math::Matrix $b --> Bool) {
    @!rows ~~ $b!rows;
}
method ACCEPTS(Math::Matrix $b --> Bool) {
    self.equal( $b );
}

method !build_is-square(Math::Matrix:D: --> Bool) {
    $!column-count == $!row-count;
}


=begin pod
=head3 is-zero

   True if every cell has value of 0.
=end pod

method !build_is-zero(Math::Matrix:D: --> Bool) {
    self.density() == 0;
}


=begin pod
=head3 is-identity

   True if every cell on the diagonal (where row index equals column index) is 1
   and any other cell is 0.

    Example:    1 0 0
                0 1 0
                0 0 1
=end pod

method !build_is-identity(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        return False unless @!rows[$r][$c] == ($r == $c ?? 1 !! 0);
    }
    True;
}


=begin pod
=head3 is-upper-triangular

   True if every cell below the diagonal (where row index is greater than column index) is 0.

    Example:    1 2 5
                0 3 8
                0 0 7
=end pod

method !build_is-upper-triangular(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        return False if @!rows[$r][$c] != 0 and $r > $c;
    }
    True;
}


=begin pod
=head3 is-lower-triangular

   True if every cell above the diagonal (where row index is smaller than column index) is 0.

    Example:    1 0 0
                2 3 0
                5 8 7
=end pod

method !build_is-lower-triangular(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        return False if @!rows[$r][$c] != 0 and $r < $c;
    }
    True;
}


=begin pod
=head3 is-diagonal

   True if only cells on the diagonal differ from 0.

    Example:    1 0 0
                0 3 0
                0 0 7
=end pod

method !build_is-diagonal(Math::Matrix:D: --> Bool) {
    return $.is-upper-triangular && $.is-lower-triangular;
}


=begin pod
=head3 is-diagonally-dominant

   True if cells on the diagonal have a bigger or equal absolute value than the
   sum of the other absolute values in the column.

   if $matrix.is-diagonally-dominant {
   $matrix.is-diagonally-dominant(:!strict)   # same thing (default)
   $matrix.is-diagonally-dominant(:strict)    # diagonal elements (DE) are stricly greater (>)
   $matrix.is-diagonally-dominant(:!strict, :along<column>) # default
   $matrix.is-diagonally-dominant(:strict,  :along<row>)    # DE > sum of rest row
   $matrix.is-diagonally-dominant(:!strict, :along<both>)   # DE >= sum of rest row and rest column
=end pod

method is-diagonally-dominant(Math::Matrix:D: Bool :$strict = False, Str :$along where {$^orient eq any <column row both>} = 'column' --> Bool) {
    return False unless self.is-square;
    my $greater = $strict ?? &[>] !! &[>=];
    my Bool $colwise;
    if $along ~~ any <column both> {
        $colwise = [and] map {my $c = $_; &$greater( @!rows[$c][$c] * 2, 
                                                     [+](map {abs $_[$c]}, @!rows)) }, ^$!row-count;
    }
    return $colwise if $along eq 'column';
    my Bool $rowwise = [and] map { &$greater( @!rows[$^r][$^r] * 2, 
                                              [+](map {abs $^c}, @!rows[$^r].flat)) }, ^$!row-count;
    return $rowwise if $along eq 'row';
    $colwise and $rowwise;
}


=begin pod
=head3 is-symmetric

    Is True if every cell with coordinates x y has same value as the cell on y x.
    In other words: $matrix and $matrix.transposed (alias T) are the same.

    Example:    1 2 3
                2 5 4
                3 4 7
=end pod

method !build_is-symmetric(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    return True if $!row-count < 2;
    for ^($!row-count - 1) -> $r {
        for $r ^..^ $!row-count -> $c {
            return False unless @!rows[$r][$c] == @!rows[$c][$r];
        }
    }
    True;
}


=begin pod
=head3 is-self-adjoint

    A Hermitian or self-adjoint matrix is equal to its transposed and conjugated.
=end pod

method !build_is-self-adjoint(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    self.T.conj ~~ self;
}


=begin pod
=head3 is-unitary

    An unitery matrix multiplied (dotProduct) with its concjugate transposed 
    derivative (.conj.T) is an identity matrix or said differently the 
    concjugate transposed matrix equals the inversed matrix.
=end pod

method !build_is-unitary(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    self.dotProduct( self.T.conj ) ~~ Math::Matrix.new-identity( $!row-count );
}


=begin pod
=head3 is-orthogonal

    An orthogonal matrix multiplied (dotProduct) with its transposed derivative (T)
    is an identity matrix or in other words transosed and inverted matrices are equal.
=end pod

method !build_is-orthogonal(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    self.dotProduct( self.T ) ~~ Math::Matrix.new-identity( $!row-count );
}


=begin pod
=head3 is-invertible

    Is True if number of rows and colums are the same (is-square) and determinant is not zero.
    All rows or colums have to be Independent vectors.
=end pod

method !build_is-invertible(Math::Matrix:D: --> Bool) {
    self.is-square and self.determinant != 0;
}


=begin pod
=head3 is-positive-definite

    True if all main minors or all Eigenvalues are strictly greater zero.
=end pod

method !build_is-positive-definite (Math::Matrix:D: --> Bool) { # with Sylvester's criterion
    return False unless self.is-square;
    return False unless self.determinant > 0;
    my $sub = Math::Matrix.new( @!rows );
    for $!row-count - 1 ... 1 -> $r {
        $sub = $sub.submatrix(0,0,$r,$r);
        return False unless $sub.determinant > 0;
    }
    True;
}


=begin pod
=head3 is-positive-semidefinite

    True if all main minors or all Eigenvalues are greater equal zero.
=end pod

method !build_is-positive-semidefinite (Math::Matrix:D: --> Bool) { # with Sylvester's criterion
    return False unless self.is-square;
    return False unless self.determinant >= 0;
    my $sub = Math::Matrix.new( @!rows );
    for $!row-count - 1 ... 1 -> $r {
        $sub = $sub.submatrix(0,0,$r,$r);
        return False unless $sub.determinant >= 0;
    }
    True;
}
################################################################################
# end of boolean matrix properties - start numeric matrix properties
################################################################################

=begin pod
=head2 Numeric Properties
=head3 size

    List of two values: number of rows and number of columns.

    say $matrix.size();
    my $dim = min $matrix.size();  
=end pod

method size(Math::Matrix:D: ){
    return $!row-count, $!column-count;
}


=begin pod
=head3 elems

    Number (count) of elements.

    say $matrix.elems();
    say +$matrix;                       # same thing
=end pod

method elems (Math::Matrix:D: --> Int) {
    $!row-count * $!column-count;
}

=begin pod
=head3 density

    my $d = $matrix.density( );   

    Density is the percentage of cell which are not zero.
=end pod


method !build_density(Math::Matrix:D: --> Rat) {
    my $valcount = 0;
    for ^$!row-count X ^$!column-count -> ($r, $c) { $valcount++ if @!rows[$r][$c] != 0 }
    $valcount / ($!row-count * $!column-count);
}


=begin pod
=head3 trace

    my $tr = $matrix.trace( ); 

    The trace of a square matrix is the sum of the cells on the main diagonal.
    In other words: sum of cells which row and column value is identical.
=end pod

method !build_trace(Math::Matrix:D: --> Numeric) {
    self.diagonal.sum;
}


=begin pod
=head3 determinant, alias det

    If you see the columns as vectors, that describe the edges of a solid,
    the determinant of a square matrix tells you the volume of that solid.
    So if the solid is just in one dimension flat, the determinant is zero too.

    my $det = $matrix.determinant( );
    my $d = $matrix.det( );             # same thing
    my $d = |$matrix|;                  # operator shortcut

=end pod

method det(Math::Matrix:D: --> Numeric )        { self.determinant }  # the usual short name
method !build_determinant(Math::Matrix:D: --> Numeric) {
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    return 1            if $!row-count == 0;
    return @!rows[0][0] if $!row-count == 1;
    if $!row-count > 4 {
        #up to 4x4 naive method is fully usable
        return [*] $.diagonal.flat if $.is-upper-triangular || $.is-lower-triangular;
        try {
            my ($L, $U, $P) = $.decompositionLU();
            return $P.inverted.det * $L.det * $U.det;
        }
    }
    my $det = 0;
    for ( σ_permutations([^$!row-count]) ) {
        my $permutation = .key;
        my $product = .value;
        for $permutation.kv -> $i, $j { $product *= @!rows[$i][$j] };
        $det += $product;
    }
    $!determinant = $det;
}

method determinant-naive(Math::Matrix:D: --> Numeric) {
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    return 1            if $!row-count == 0;
    return @!rows[0][0] if $!row-count == 1;
    my $det = 0;
    for ( σ_permutations([^$!row-count]) ) {
        my $permutation = .key;
        my $product = .value;
        for $permutation.kv -> $i, $j { $product *= @!rows[$i][$j] };
        $det += $product;
    }
    $det;
}


=begin pod
=head3 rank

    my $r = $matrix.rank( );

    rank is the number of independent row or column vectors
    or also called independent dimensions
    (thats why this command is sometimes calles dim)

=end pod

method !build_rank(Math::Matrix:D: --> Int) {
    my $rank = 0;
    my @clone =  @!rows.clone();
    for ^$!column-count -> $c {            # make upper triangle via gauss elimination
        last if $rank == $!row-count;      # rank cant get bigger thean dim
        my $swap_row_nr = $rank;
        $swap_row_nr++ while $swap_row_nr < $!row-count and @clone[$swap_row_nr][$c] == 0;
        next if $swap_row_nr == $!row-count;
        (@clone[$rank], @clone[$swap_row_nr]) = (@clone[$swap_row_nr], @clone[$rank]);
        for $rank + 1 ..^ $!row-count -> $r {
            next if @clone[$r][$c] == 0;
            my $q = @clone[$rank][$c] / @clone[$r][$c];
            @clone[$r] = @clone[$rank] >>-<< $q <<*<< @clone[$r];
        }
        $rank++;
    }
    $rank;
}


=begin pod
=head3 kernel

    my $tr = $matrix.kernel( );
    kernel of matrix, number of dependent rows or columns

=end pod

method !build_kernel(Math::Matrix:D: --> Int) {
    min(self.size) - self.rank;
}


=begin pod
=head3 norm

    my $norm = $matrix.norm( );           # euclidian norm (L2, p = 2)
    my $norm = ||$matrix||;               # operator shortcut to do the same
    my $norm = $matrix.norm(1);           # p-norm, L1 = sum of all cells
    my $norm = $matrix.norm(p:<4>,q:<3>); # p,q - norm, p = 4, q = 3
    my $norm = $matrix.norm(p:<2>,q:<2>); # Frobenius norm
    my $norm = $matrix.norm('max');       # maximum norm - biggest absolute value of a cell
    $matrix.norm('row-sum');              # row sum norm - biggest abs. value-sum of a row
    $matrix.norm('column-sum');           # column sum norm - same column wise
=end pod


multi method norm(Math::Matrix:D: Positive_Int :$p = 2, Positive_Int :$q = 1 --> Numeric) {
    my $norm = 0;
    for ^$!column-count -> $c {
        my $col_sum = 0;
        for ^$!row-count -> $r {  $col_sum += abs(@!rows[$r][$c]) ** $p }
        $norm += $col_sum ** ($q / $p);
    }
    $norm ** (1/$q);
}

multi method norm(Math::Matrix:D: Str $which where * eq 'row-sum' --> Numeric) {
    max map {[+] map {abs $_}, @$_}, @!rows;
}

multi method norm(Math::Matrix:D: Str $which where * eq 'column-sum' --> Numeric) {
    max map {my $c = $_; [+](map {abs $_[$c]}, @!rows) }, ^$!column-count;
}

multi method norm(Math::Matrix:D: Str $which where * eq 'max' --> Numeric) {
    max map {max map {abs $_},  @$_}, @!rows;
}


=begin pod
=head3 condition

    my $c = $matrix.condition( );        

    Condition number of a matrix is L2 norm * L2 of inverted matrix.

=end pod

multi method condition(Math::Matrix:D: --> Numeric) {
    self.norm() * self.inverted().norm();
}


################################################################################
# end of numeric matrix properties - start create derivative matrices
################################################################################

=begin pod
=head2 Derivative Matrices
=head3 transposed, alias T

    returns a new, transposed Matrix, where rows became colums and vice versa.

    Math::Matrix.new([[1,2,3],[3,4,6]]).transposed

    Example:   [1 2 3].T  =  1 4       
               [4 5 6]       2 5
                             3 6
=end pod

method T(Math::Matrix:D: --> Math::Matrix:D  )         { self.transposed }
method transposed(Math::Matrix:D: --> Math::Matrix:D ) {
    my @transposed;
    for ^$!row-count X ^$!column-count -> ($r, $c) { @transposed[$c][$r] = @!rows[$r][$c] }
    Math::Matrix.new( @transposed );
}


=begin pod
=head3 inverted

    Inverse matrix regarding to matrix multiplication.
    The dot product of a matrix with its inverted results in a identity matrix
    (neutral element in this group).
    Matrices that have a square form and a full rank can be inverted.
    Check this with the method .is-invertible.
=end pod

method inverted(Math::Matrix:D: --> Math::Matrix:D) {
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    fail "Matrix is not invertible, or singular because defect (determinant = 0)" if self.determinant == 0;
    my @clone = self!clone_rows();
    my @inverted = self!identity_array( $!row-count );
    for ^$!row-count -> $c {
        my $swap_row_nr = $c;       # make sure that diagonal element != 0, later == 1
        $swap_row_nr++ while @clone[$swap_row_nr][$c] == 0;
        (@clone[$c], @clone[$swap_row_nr])       = (@clone[$swap_row_nr], @clone[$c]);
        (@inverted[$c], @inverted[$swap_row_nr]) = (@inverted[$swap_row_nr], @inverted[$c]);
        @inverted[$c] =  @inverted[$c] >>/>>  @clone[$c][$c];
        @clone[$c]    =  @clone[$c]    >>/>>  @clone[$c][$c];
        for $c + 1 ..^ $!row-count -> $r {
            @inverted[$r] = @inverted[$r]  >>-<<  @clone[$r][$c] <<*<< @inverted[$c];
            @clone[$r]    = @clone[$r]  >>-<<  @clone[$r][$c] <<*<< @clone[$c];
        }
    }
    for reverse(1 ..^ $!column-count) -> $c {
        for ^$c -> $r {
            @inverted[$r] = @inverted[$r]  >>-<<  @clone[$r][$c] <<*<< @inverted[$c];
            @clone[$r]    = @clone[$r]  >>-<<  @clone[$r][$c] <<*<< @clone[$c];
        }
    }
    Math::Matrix.new( @inverted );
}


=begin pod
=head3 negated

    my $new = $matrix.negated();    # invert sign of all cells
    my $neg = - $matrix;            # works too

=end pod

method negated(Math::Matrix:D: --> Math::Matrix:D ) {
    self.map( - * );
}


=begin pod
=head3 conjugated, alias conj

    my $c = $matrix.conjugated();    # change every value to its complex conjugated
    my $c = $matrix.conj();          # works too (official Perl 6 name)

=end pod
method conj(Math::Matrix:D: --> Math::Matrix:D  )         { self.conjugated }
method conjugated(Math::Matrix:D: --> Math::Matrix:D ) {
    self.map( { $_.conj} );
}



=begin pod
=head3 reduced-row-echelon-form, alias rref

    my $rref = $matrix.reduced-row-echelon-form();
    my $rref = $matrix.rref();

    Return the reduced row echelon form of a matrix, a.k.a. row canonical form
=end pod

method reduced-row-echelon-form(Math::Matrix:D: --> Math::Matrix:D) {
    my @ref = self!clone_rows();
    my $lead = 0;
    MAIN: for ^$!row-count -> $r {
        last MAIN if $lead >= $!column-count;
        my $i = $r;
        while @ref[$i][$lead] == 0 {
            $i++;
            if $!row-count == $i {
                $i = $r;
                $lead++;
                last MAIN if $lead == $!column-count;
            }
        }
        @ref[$i, $r] = @ref[$r, $i];
        my $lead_value = @ref[$r][$lead];
        @ref[$r] »/=» $lead_value;
        for ^$!row-count -> $n {
            next if $n == $r;
            @ref[$n] »-=» @ref[$r] »*» @ref[$n][$lead];
        }
        $lead++;
    }
    return Math::Matrix.new( @ref );
}
method rref(Math::Matrix:D: --> Math::Matrix:D) {
    self.reduced-row-echelon-form;
}

################################################################################
# end of derivative matrices - start decompositions
################################################################################

=begin pod
=head2 Decompositions

=head3 decompositionLU

    my ($L, $U, $P) = $matrix.decompositionLU( );
    $L dot $U eq $matrix dot $P;         # True
    my ($L, $U) = $matrix.decompositionLUC(:!pivot);
    $L dot $U eq $matrix;                # True

    $L is a left triangular matrix and $R is a right one
    Without pivotisation the marix has to be invertible (square and full ranked).
    In case you whant two unipotent triangular matrices and a diagonal (D):
    use the :diagonal option, which can be freely combined with :pivot.

    my ($L, $D, $U, $P) = $matrix.decompositionLU( :diagonal );
    $L dot $D dot $U eq $matrix dot $P;  # True

=end pod

# LU factorization with optional partial pivoting and optional diagonal matrix
multi method decompositionLU(Math::Matrix:D: Bool :$pivot = True, :$diagonal = False) {
    fail "Not an square matrix" unless self.is-square;
    fail "Has to be invertible when not using pivoting" if not $pivot and not self.is-invertible;
    my $size = self!row-count;
    my @L = self!identity_array( $size );
    my @U = self!clone_rows( );
    my @P = self!identity_array( $size );
    for 0 .. $size-2 -> $c {
        if $pivot {
            my $maxrow = $c;
            for $c+1 ..^$size -> $r { $maxrow = $c if @U[$maxrow][$c] < @U[$r][$c] }
            (@U[$maxrow], @U[$c]) = (@U[$c], @U[$maxrow]);
            (@P[$maxrow], @P[$c]) = (@P[$c], @P[$maxrow]);
        }
        for $c+1 ..^$size -> $r {
            next if @U[$r][$c] == 0;
            my $q = @L[$r][$c] = @U[$r][$c] / @U[$c][$c];
            @U[$r] = @U[$r] >>-<< $q <<*<< @U[$c];
        }
    }

    if $diagonal {
        my @D;
        for 0 ..^ $size -> $c {
            push @D, @U[$c][$c];
            @U[$c][$c] = 1;
        }
        $pivot ?? (Math::Matrix!new-lower-triangular(@L), Math::Matrix.new-diagonal(@D), Math::Matrix!new-upper-triangular(@U), Math::Matrix.new(@P))
               !! (Math::Matrix!new-lower-triangular(@L), Math::Matrix.new-diagonal(@D), Math::Matrix!new-upper-triangular(@U));
    }
    $pivot ?? (Math::Matrix!new-lower-triangular(@L), Math::Matrix!new-upper-triangular(@U), Math::Matrix.new(@P))
           !! (Math::Matrix!new-lower-triangular(@L), Math::Matrix!new-upper-triangular(@U));
}


=begin pod
=head3 decompositionLUCrout

    my ($L, $U) = $matrix.decompositionLUCrout( );
    $L dot $U eq $matrix;                # True

    $L is a left triangular matrix and $R is a right one
    This decomposition works only on invertible matrices (square and full ranked).
=end pod

method decompositionLUCrout(Math::Matrix:D: ) {
    fail "Not square matrix" unless self.is-square;
    my $sum;
    my $size = self!row-count;
    my $U = self!identity_array( $size );
    my $L = self!zero_array( $size );

    for 0 ..^$size -> $j {
        for $j ..^$size -> $i {
            $sum = [+] map {$L[$i][$_] * $U[$_][$j]}, 0..^$j;
            $L[$i][$j] = @!rows[$i][$j] - $sum;
        }
        if $L[$j][$j] == 0 { fail "det(L) close to 0!\n Can't divide by 0...\n" }

        for $j ..^$size -> $i {
            $sum = [+] map {$L[$j][$_] * $U[$_][$i]}, 0..^$j;
            $U[$j][$i] = (@!rows[$j][$i] - $sum) / $L[$j][$j];
        }
    }
    return Math::Matrix.new($L), Math::Matrix.new($U);
}


=begin pod
=head3 decompositionCholesky

    my $D = $matrix.decompositionCholesky( );  # $D is a left triangular matrix
    $D dot $D.T eq $matrix;                    # True 

    This decomposition works only on symmetric and definite positive matrices.
=end pod

method decompositionCholesky(Math::Matrix:D: --> Math::Matrix:D) {
    fail "Not symmetric matrix" unless self.is-symmetric;
    fail "Not positive definite" unless self.is-positive-definite;
    my @D = self!clone_rows();
    for 0 ..^$!row-count -> $k {
        @D[$k][$k] -= @D[$k][$_]**2 for 0 .. $k-1;
        @D[$k][$k]  = sqrt @D[$k][$k];
        for $k+1 ..^ $!row-count -> $i {
            @D[$i][$k] -= @D[$i][$_] * @D[$k][$_] for 0 ..^ $k ;
            @D[$i][$k]  = @D[$i][$k] / @D[$k][$k];
        }
    }
    for ^$!row-count X ^$!column-count -> ($r, $c) { @D[$r][$c] = 0 if $r < $c }
    #return Math::Matrix.BUILD( rows => @D, is-lower-triangular => True );
    return Math::Matrix!new-lower-triangular( @D );
}


################################################################################
# end of decompositions - start matrix operations
################################################################################

=begin pod
=head2 Matrix Math Operations
=head3 add

    Example:    1 2  +  5    =  6 7 
                3 4             8 9

                1 2  +  2 3  =  3 5
                3 4     4 5     7 9


    my $sum = $matrix.add( $matrix2 );  # cell wise addition of 2 same sized matrices
    my $s = $matrix + $matrix2;         # works too

    my $sum = $matrix.add( $number );   # adds number from every cell 
    my $s = $matrix + $number;          # works too
=end pod

multi method add(Math::Matrix:D: Numeric $r --> Math::Matrix:D ) {
    self.map( * + $r );
}

multi method add(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b!row-count and $!column-count == $b!column-count } --> Math::Matrix:D ) {
    my @sum;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        @sum[$r][$c] = @!rows[$r][$c] + $b!rows[$r][$c];
    }
    Math::Matrix.new( @sum );
}


=begin pod
=head3 subtract

    Works analogous to add - it's just for convenance.

    my $diff = $matrix.subtract( $number );   # subtracts number from every cell (scalar subtraction)
    my $sd = $matrix - $number;               # works too
    my $sd = $number - $matrix ;              # works too

    my $diff = $matrix.subtract( $matrix2 );  # cell wise subraction of 2 same sized matrices
    my $d = $matrix - $matrix2;               # works too
=end pod

multi method subtract(Math::Matrix:D: Numeric $r --> Math::Matrix:D ) {
    self.map( * - $r );
}

multi method subtract(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b!row-count and $!column-count == $b!column-count } --> Math::Matrix:D ) {
    my @subtract;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        @subtract[$r][$c] = @!rows[$r][$c] - $b!rows[$r][$c];
    }
    Math::Matrix.new( @subtract );
}


=begin pod
=head3 add-row

    Add a vector (row or col of some matrix) to a row of the matrix.
    In this example we add (2,3) to the second row.

    Math::Matrix.new( [[1,2],[3,4]] ).add-row(1,(2,3));

    Example:    1 2  +       =  1 2
                3 4    2 3      5 7
=end pod

method add-row(Math::Matrix:D: Int $row, @row where {.all ~~ Numeric} --> Math::Matrix:D ) {
    fail X::OutOfRange.new(
        :what<Row Index> , :got($row), :range("0..{$!row-count - 1}")
    ) unless 0 <= $row < $!row-count;
    fail "Matrix has $!column-count columns, but got "~ +@row ~ "element row." unless $!column-count == +@row;
    my @m = AoA_clone(@!rows);
    @m[$row] = @m[$row] <<+>> @row;
    Math::Matrix.new( @m );
}


=begin pod
=head3 add-column

    Analog to add-row:
    Math::Matrix.new( [[1,2],[3,4]] ).add-column(1,(2,3));

    Example:    1 2  +   2   =  1 4
                3 4      3      3 7
=end pod

method add-column(Math::Matrix:D: Int $col, @col where {.all ~~ Numeric} --> Math::Matrix:D ) {
    fail X::OutOfRange.new(
        :what<Column Index> , :got($col), :range("0..{$!column-count - 1}")
    ) unless 0 <= $col < $!column-count;
    fail "Matrix has $!row-count rows, but got "~ +@col ~ "element column." unless $!row-count == +@col;
    my @m = AoA_clone(@!rows);
    @col.keys.map:{ 
        @m[$_][$col] += @col[$_] 
    };
    Math::Matrix.new( @m );
}


=begin pod
=head3 multiply

    In scalar multiplication each cell of the matrix gets multiplied with the same
    number (scalar). In addition to that, this method can multiply two same sized
    matrices, by multipling the cells with the came coordinates from each operand.

    Example:    1 2  *  5    =   5 10 
                3 4             15 20

                1 2  *  2 3  =   2  6
                3 4     4 5     12 20

    my $product = $matrix.multiply( $number );   # multiply every cell with number
    my $p = $matrix * $number;                   # works too

    my $product = $matrix.multiply( $matrix2 );  # cell wise multiplication of same size matrices
    my $p = $matrix * $matrix2;                  # works too

=end pod

multi method multiply(Math::Matrix:D: Numeric $r --> Math::Matrix:D ) {
    self.map( * * $r );
}

multi method multiply(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b!row-count and $!column-count == $b!column-count } --> Math::Matrix:D ) {
    my @multiply;
    for ^$!row-count X ^$!column-count -> ($r, $c) {
        @multiply[$r][$c] = @!rows[$r][$c] * $b!rows[$r][$c];
    }
    Math::Matrix.new( @multiply );
}


=begin pod
=head3 multiply-row

    Multiply scalar number to each cell of a row.

    Math::Matrix.new( [[1,2],[3,4]] ).multiply-row(0,2);

    Example:    1 2  * 2     =  2 4
                3 4             3 4
=end pod

method multiply-row(Math::Matrix:D: Int $row, Numeric $factor --> Math::Matrix:D ) {
    self.map-row($row,{$_ * $factor});
}


=begin pod
=head3 multiply-column

    Multiply scalar number to each cell of a column.

    Math::Matrix.new( [[1,2],[3,4]] ).multiply-row(0,2);

    Example:    1 2          =  2 2
                3 4             6 4
            
               *2
=end pod

method multiply-column(Math::Matrix:D: Int $column, Numeric $factor --> Math::Matrix:D ) {
    self.map-column($column,{$_ * $factor});
}


=begin pod
=head3 dotProduct

    Matrix multiplication of two fitting matrices (colums left == rows right).

    Example:    1 2  *  2 3  =  10 13  =  1*2+2*4  1*3+2*5
                3 4     4 5     22 29     3*2+4*4  3*3+4*5

    my $product = $matrix1.dotProduct( $matrix2 )
    my $c = $a dot $b;              # works too as operator alias
    my $c = $a ⋅ $b;                # unicode operator alias

    A shortcut for multiplication is the power - operator **
    my $c = $a **  3;               # same as $a dot $a dot $a
    my $c = $a ** -3;               # same as ($a dot $a dot $a).inverted
    my $c = $a **  0;               # created an right sized identity matrix

=end pod

multi method dotProduct(Math::Matrix:D: Math::Matrix $b where { $a!column-count == $b!row-count} --> Math::Matrix:D ) {
    my @product;
    for ^$!row-count X ^$b!column-count -> ($r, $c) {
        @product[$r][$c] += @!rows[$r][$_] * $b!rows[$_][$c] for ^$b!row-count;
    }
    Math::Matrix.new( @product );
}


=begin pod
=head3 tensorProduct

    The tensor product between a matrix a of size (m,n) and a matrix b of size
    (p,q) is a matrix c of size (m*p,n*q). All matrices you get by multiplying
    an element (cell) of matrix a with matrix b (as in $a.multiply($b.cell(..,..))
    concatinated result in matrix c. 
    (Or replace in a each cell with its product with b.)

    Example:    1 2  *  2 3   =  1*[2 3] 2*[2 3]  =  2  3  4  6
                3 4     4 5        [4 5]   [4 5]     4  5  8 10
                                 3*[2 3] 4*[2 3]     6  9  8 12
                                   [4 5]   [4 5]     8 15 16 20
    
    my $c = $matrixa.tensorProduct( $matrixb );
    my $c = $a x $b;                # works too as operator alias
    my $c = $a ⊗ $b;                # unicode operator alias


=end pod

multi method tensorProduct(Math::Matrix:D: Math::Matrix $b  --> Math::Matrix:D) {
    my @product;
    for @!rows -> $arow {
        for $b!rows -> $brow {
            @product.push([ ($arow.list.map: { $brow.flat >>*>> $_ }).flat ]);
        }
    }
    Math::Matrix.new( @product );
}

################################################################################
# end of math matrix operations - start structural matrix operations
################################################################################

=begin pod
=head2 Structural Matrix Operations
=head3 map

    Like the built in map it iterates over all elements, running a code block.
    The results for a new matrix.

    say Math::Matrix.new([[1,2],[3,4]]).map(* + 1);    # prints:

    2 3
    4 5
=end pod

method map(Math::Matrix:D: &coderef --> Math::Matrix:D) {
    Math::Matrix.new( [ @!rows.map: {
            [ $_.map( &coderef ) ]
    } ] );
}


=begin pod
=head3 map-row

    Map only specified row (row number is first parameter).
    
    say Math::Matrix.new([[1,2],[3,4]]).map-row(1, {$_ + 1}); # prints:

    1 2
    4 5
=end pod

method map-row(Math::Matrix:D: Int $row, &coderef --> Math::Matrix:D ) {
    fail X::OutOfRange.new(
        :what<Row Index> , :got($row), :range("0..{$!row-count - 1}")
    ) unless 0 <= $row < $!row-count;
    my @m = AoA_clone(@!rows);
    @m[$row] = @m[$row].map(&coderef);
    Math::Matrix.new( @m );
}

=begin pod
=head3 map-column

    say Math::Matrix.new([[1,2],[3,4]]).map-column(1, {0}); # prints:

    1 0
    3 0
=end pod


method map-column(Math::Matrix:D: Int $col, &coderef --> Math::Matrix:D ) {
    fail X::OutOfRange.new(
        :what<Column Index> , :got($col), :range("0..{$!column-count - 1}")
    ) unless 0 <= $col < $!column-count;
    my @m = AoA_clone(@!rows);
    (^$!column-count).map:{ @m[$_;$col] = &coderef( @m[$_;$col] ) };
    Math::Matrix.new( @m );
}

=begin pod
=head3 reduce

    Like the built in reduce method, it iterates over all elements and joins
    them into one value, by applying the given operator or method
    to the previous result and the next element. I starts with the cell [0][0]
    and moving from left to right in the first row and continue with the first
    cell of the next row.
    
    Math::Matrix.new( [[1,2],[3,4]] ).reduce(&[+]);      # 10
    Math::Matrix.new( [[1,2],[3,4]] ).reduce(&[*]);      # 10

=end pod

method reduce(Math::Matrix:D: &coderef ) {
    (@!rows.map: {$_.flat}).flat.reduce( &coderef );
}


=begin pod
=head3 reduce-rows

    Reduces (as described above) every row into one value, so the overall result
    will be a list. In this example we calculate the sum of all cells in a row:
    
    say Math::Matrix.new( [[1,2],[3,4]] ).reduce-rows(&[+]);     # prints (3, 7)
=end pod

method reduce-rows (Math::Matrix:D: &coderef){
    @!rows.map: { $_.flat.reduce( &coderef ) };
}

method reduce-columns (Math::Matrix:D: &coderef){
    (^$!column-count).map: { self.column($_).reduce( &coderef ) }
}


method cat-horizontally(){ 

}

# method split (){ }
# method join (){ }
