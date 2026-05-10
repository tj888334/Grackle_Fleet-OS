--- A basic matrix type and common matrix operations. This may be useful
-- when working with linear algebra, transformations, and mathematical computations.
--
-- An introduction to matrices can be found on [Wikipedia][wiki].
--
-- [wiki]: https://en.wikipedia.org/wiki/Matrix_(mathematics)
--
-- If you are interested in using [CCSharp][ccsharp], here is the compatible [Matrix.cs][ccsharp-matrix] file.
--
-- [ccsharp]: https://github.com/monkeymanboy/CCSharp
-- [ccsharp-matrix]: https://github.com/monkeymanboy/CCSharp/blob/master/src/CCSharp/AdvancedMath/Matrix.cs
--
-- @module matrix
-- @author TechTastic

local expect = dofile("rom/modules/main/cc/expect.lua").expect
local metatable

--- Constructors
--
-- @section Constructors

--- Constructs a new matrix of rows by columns, filling it using the provided function or scalar.
--
-- @tparam number rows The number of rows in the matrix
-- @tparam number columns The number of columns in the matrix
-- @tparam function|number|nil func A function taking (row, column) to generate values, or a scalar to fill all elements
-- @treturn Matrix A new matrix
-- @usage m = matrix.new(3, 3, function(r, c) return r + c end)
-- @usage m = matrix.new(2, 4, 5) -- fills all elements with 5
-- @usage m = matrix.new(2, 2) -- fills all elements with 1
-- @export
function new(rows, columns, func)
    expect(1, rows, "number", "nil")
    expect(2, columns, "number", "nil")
    expect(3, func, "function", "number", "nil")

    local m = {}
    m.rows = rows or 1
    m.columns = columns or 1
    for r = 1, rows do
        m[r] = {}
        for c = 1, columns do
            if type(func) == "function" then
                m[r][c] = func(r, c)
            elseif type(func) == "number" then
                m[r][c] = func
            else
                m[r][c] = 1
            end
        end
    end
    return setmetatable(m, metatable)
end

--- Constructs a matrix from a 2D array (table of tables).
--
-- @tparam table arr A 2D array representing the matrix data
-- @treturn Matrix A new matrix
-- @usage m = matrix.from2DArray({{1, 2}, {3, 4}})
-- @export
function from2DArray(arr)
    expect(1, arr, "table")
    if getmetatable(arr) ~= getmetatable({}) then
        error("Invalid Argument! Takes a 2D array!")
    end

    return new(#arr, #arr[1], function(r, c) return arr[r][c] or 0 end)
end

--- Constructs a matrix from a [Vector](https://tweaked.cc/module/vector.html), as either a row or column matrix.
--
-- @tparam table v The vector to convert
-- @tparam boolean row Whether to create a row matrix (true) or column matrix (false). Defaults to true.
-- @treturn Matrix A new matrix representing the vector
-- @usage m = matrix.fromVector(vector.new(1, 2, 3), true) -- row matrix
-- @usage m = matrix.fromVector(vector.new(1, 2, 3), false) -- column matrix
-- @export
function fromVector(v, row)
    expect(1, v, "vector")
    if (getmetatable(v) or {}).__name ~= "vector" then expect(1, v, "vector") end
    expect(2, row, "boolean", "nil")

    row = row or true
    local m = {}
    if row then
        m[1] = {v.x, v.y, v.z}
    else
        m[1] = {v.x}
        m[2] = {v.y}
        m[3] = {v.z}
    end
    return from2DArray(m)
end

--- Constructs a rotation matrix from a quaternion.
--
-- @tparam table q The quaternion to convert
-- @treturn Matrix A new 3x3 rotation matrix
-- @usage m = matrix.fromQuaternion(quaternion.new(1, vector.new(0, 0, 0)))
-- @export
-- @see quaternion
function fromQuaternion(q)
    if not quaternion then
        error("Quaternion API is not loaded!")
    end
    expect(1, q, "table")
    if (getmetatable(q) or {}).__name ~= "quaternion" then expect(1, v, "quaternion") end

    q = q:normalize()
    local w = q.a
    local x = q.v.x
    local y = q.v.y
    local z = q.v.z

    local m = {
        {1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)},
        {2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)},
        {2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)}
    }
    return from2DArray(m)
end

--- Constructs an identity matrix of given dimensions.
--
-- @tparam number rows The number of rows
-- @tparam number columns The number of columns
-- @treturn Matrix A new identity matrix
-- @usage m = matrix.identity(3, 3)
-- @export
function identity(rows, columns)
    return new(rows, columns)
end

--- Utility Functions
--
-- @section Utility Functions

--- Solves the system of linear equations Ax = b for x.
--
-- @tparam Matrix A The coefficient matrix
-- @tparam Matrix b The right-hand side matrix (column vector)
-- @treturn Matrix The solution matrix x
-- @usage x = matrix.solve(A, b)
-- @export
function solve(A, b, tol)
    expect(1, A, "table")
    if (getmetatable(A) or {}).__name ~= "matrix" then expect(1, A, "matrix") end
    expect(2, b, "table")
    if (getmetatable(b) or {}).__name ~= "matrix" then expect(2, b, "matrix") end
    expect(3, tol, "number", "nil")
    tol = tol or 1e-10

    if A.rows ~= A.columns then
        error("Matrix A must be square!")
    end
    if b.columns ~= 1 or b.rows ~= A.rows then
        error("Matrix b must be a column vector with the same number of rows as A!")
    end

    local n = A.rows

    local aug = matrix.new(n, n + 1, function(r, c)
        if c <= n then
            return A[r][c]
        else
            return b[r][1]
        end
    end)

    local warning = nil
    for col = 1, n do
        local maxVal, maxRow = math.abs(aug[col][col]), col
        for r = col + 1, n do
            if math.abs(aug[r][col]) > maxVal then
                maxVal = math.abs(aug[r][col])
                maxRow = r
            end
        end

        if maxVal < tol then
            error("Matrix is singular or nearly singular! No unique solution exists.")
        elseif maxVal < 1e-6 then
            warning = "Warning: Matrix may be ill-conditioned"
        end

        aug[col], aug[maxRow] = aug[maxRow], aug[col]

        for r = col + 1, n do
            local factor = aug[r][col] / aug[col][col]
            for c = col, n + 1 do
                aug[r][c] = aug[r][c] - factor * aug[col][c]
            end
        end
    end

    local x = {}
    for i = 1, n do
        x[i] = {0}
    end

    for r = n, 1, -1 do
        local sum = aug[r][n + 1]
        for c = r + 1, n do
            sum = sum - aug[r][c] * x[c][1]
        end
        x[r][1] = sum / aug[r][r]
    end

    return from2DArray(x), warning
end

--- A matrix, with dimensions `rows` x `columns`.
--
-- This is suitable for representing linear transformations, systems of equations,
-- and general numerical computations.
--
-- @type Matrix
local matrix = {
    --- The number of rows in the matrix.
    -- @field rows
    -- @tparam number rows

    --- The number of columns in the matrix.
    -- @field columns
    -- @tparam number columns

    --- Adds two matrices together, or adds a scalar to all elements.
    -- Supports broadcasting with row vectors and column vectors.
    --
    -- @tparam Matrix self The first matrix to add
    -- @tparam Matrix|number other The second matrix, scalar, or vector to add
    -- @treturn Matrix The resulting matrix
    -- @usage m1:add(m2)
    -- @usage m1 + m2
    -- @usage m + 5
    add = function(self, other)
        expect(1, self, "table", "number")
        if type(self) == "table" and (getmetatable(self) or {}).__name ~= "matrix" then expect(1, self, "matrix", "number") end
        expect(2, other, "table", "number")
        if type(other) == "table" and (getmetatable(other) or {}).__name ~= "matrix" then expect(2, other, "matrix", "number") end

        if type(self) == "number" then
            return other + self
        end

        return new(self.rows, self.columns, function(r, c)
            local val = self[r][c]
            if type(other) == "number" then
                return val + other
            elseif other.rows == self.rows and other.columns == 1 then
                return val + other[r][1]
            elseif other.columns == self.columns and other.rows == 1 then
                return val + other[1][c]
            elseif other.rows == self.rows or other.columns == self.columns then
                return val + other[r][c]
            else
                error("Invalid Argument! Takes a scalar value, a vector matrix or another matrix of the same dimensions!")
            end
        end)
    end,

    --- Subtracts two matrices, or subtracts a scalar from all elements.
    --
    -- @tparam Matrix self The matrix to subtract from
    -- @tparam Matrix|number other The matrix or scalar to subtract
    -- @treturn Matrix The resulting matrix
    -- @usage m1:sub(m2)
    -- @usage m1 - m2
    sub = function(self, other)
        return self + (-other)
    end,

    --- Multiplies a matrix by a scalar or performs matrix multiplication.
    --
    -- @tparam Matrix self The matrix to multiply
    -- @tparam Matrix|number other The scalar or matrix to multiply with
    -- @treturn Matrix The resulting matrix
    --      Note: For matrix multiplication, the number of columns in self must equal the number of rows in other
    -- @usage m:mul(3)
    -- @usage m * 3
    -- @usage m1:mul(m2)
    -- @usage m1 * m2
    mul = function(self, other)
        expect(1, self, "table", "number")
        if type(self) == "table" and (getmetatable(self) or {}).__name ~= "matrix" then expect(1, self, "matrix", "number") end
        expect(2, other, "table", "number")
        if type(other) == "table" and (getmetatable(other) or {}).__name ~= "matrix" then expect(2, other, "matrix", "number") end

        if type(self) == "number" then
            return other * self
        end

        if type(other) == "number" then
            return new(self.rows, self.columns, function(r, c) return self[r][c] * other end)
        elseif type(other) == "table" and self.columns == other.rows then
            return new(self.rows, other.columns, function(r, c)
                local sum = 0
                for k = 1, self.columns do
                    sum = sum + self[r][k] * other[k][c]
                end
                return sum
            end)
        else
            error("Invalid Argument! Takes a scalar value or another matrix whose columns equal the first matrix's number of rows!")
        end
    end,

    --- Divides a matrix by a scalar or another matrix.
    --
    -- @tparam Matrix self The matrix to divide
    -- @tparam Matrix|number other The scalar or matrix to divide by
    -- @treturn Matrix The resulting matrix
    --      Note: Division by a matrix is performed by multiplying by its inverse
    -- @usage m:div(2)
    -- @usage m / 2
    -- @usage m1:div(m2)
    -- @usage m1 / m2
    div = function(self, other)
        expect(1, self, "table", "number")
        if type(self) == "table" and (getmetatable(self) or {}).__name ~= "matrix" then expect(1, self, "matrix", "number") end
        expect(2, other, "table", "number")
        if type(other) == "table" and (getmetatable(other) or {}).__name ~= "matrix" then expect(2, other, "matrix", "number") end

        if type(self) == "number" then
            return other:inverse() * self
        elseif type(other) == "number" then
            return self * (1 / other)
        else
            return self * other:inverse()
        end
    end,

    --- Negates all elements in a matrix.
    --
    -- @tparam Matrix self The matrix to negate
    -- @treturn Matrix The resulting negated matrix
    -- @usage m:unm()
    -- @usage -m
    unm = function(self)
        return self * -1
    end,

    --- Raises a square matrix to a non-negative integer power.
    --
    -- @tparam Matrix self The matrix to raise to a power
    -- @tparam number n The non-negative integer power
    -- @treturn Matrix The resulting matrix
    --      Note: Raising to power 0 returns the identity matrix
    -- @usage m:pow(3)
    -- @usage m ^ 3
    pow = function(self, n)
        expect(1, n, "number")
        if self.rows ~= self.columns then
            error("Must be a square matrix to raise to a power!")
        end
        if type(n) ~= "number" or n < 0 or n ~= math.floor(n) then
            error("Power must be a non-negative integer!")
        end

        if n == 0 then
            return identity(self.rows, self.columns)
        end

        local result = self
        for i = 2, n do
            result = result * self
        end
        return result
    end,

    --- Computes the total number of elements in the matrix.
    --
    -- @tparam Matrix self The matrix to measure
    -- @treturn number The total number of elements (rows * columns)
    -- @usage m:length()
    -- @usage #m
    length = function(self)
        return self.rows * self.columns
    end,

    --- Creates a string representation of the matrix.
    --
    -- @tparam Matrix self The matrix to stringify
    -- @treturn string The resulting string with each row on a new line
    -- @usage m:tostring()
    -- @usage m .. ""
    tostring = function(self)
        local s = ""
        for r = 1, self.rows do
            if #s > 0 then
                s = s .. "\n"
            end
            s = s .. "{ "
            for c = 1, self.columns do
                s = s .. tostring(self[r][c]) .. " "
            end
            s = s .. "}"
        end
        return s
    end,

    --- Determines if two matrices are equal.
    --
    -- @tparam Matrix self The first matrix to test
    -- @tparam Matrix other The other matrix to test against
    -- @treturn boolean True if the matrices have the same dimensions and all elements are equal
    -- @usage m1:equals(m2)
    -- @usage m1 == m2
    equals = function(self, other)
        expect(1, self, "table")
        if (getmetatable(self) or {}).__name ~= "matrix" then expect(1, self, "matrix") end
        expect(2, other, "table")
        if (getmetatable(other) or {}).__name ~= "matrix" then expect(2, other, "matrix") end

        if type(self) == type(other) and self.rows == other.rows and self.columns == other.columns then
            local identical = true
            for r = 1, self.rows do
                for c = 1, self.columns do
                    identical = self[r][c] == other[r][c]
                    if not identical then
                        return false
                    end
                end
            end
            return true
        end
        return false
    end,

    --- Computes the minor matrix by removing a specified row and column.
    --
    -- @tparam Matrix self The matrix to use
    -- @tparam number row The row index to remove
    -- @tparam number column The column index to remove
    -- @treturn Matrix The resulting minor matrix
    -- @usage m:minor(1, 2)
    minor = function(self, row, column)
        expect(1, row, "number")
        expect(2, column, "number")
        if row < 1 or row > self.rows or column < 1 or column > self.columns then
            error("Row and column indices must be within matrix bounds!")
        end

        return new(self.rows - 1, self.columns - 1, function(r, c)
            local src_r = r >= row and r + 1 or r
            local src_c = c >= column and c + 1 or c
            return self[src_r][src_c]
        end)
    end,

    --- Computes the determinant of a square matrix.
    --
    -- @tparam Matrix self The matrix to use
    -- @treturn number The determinant value
    -- @usage m:determinant()
    determinant = function(self)
        if self.rows == 0 or self.columns == 0 then
            return 0
        end
        if self.rows ~= self.columns then
            error("Must be a square matrix to calculate the determinant!")
        end
        if self.rows == 2 then
            return self[1][1] * self[2][2] - self[1][2] * self[2][1]
        end

        local det = 0
        for c = 1, self.columns do
            local cofactor = ((-1) ^ (1 + c)) * self[1][c]
            det = det + cofactor * self:minor(1, c):determinant()
        end

        return det
    end,

    --- Computes the transpose of the matrix (rows become columns).
    --
    -- @tparam Matrix self The matrix to transpose
    -- @treturn Matrix The resulting transposed matrix
    -- @usage m:transpose()
    transpose = function(self)
        return new(self.columns, self.rows, function(r, c) return self[c][r] end)
    end,

    --- Computes the cofactor matrix.
    --
    -- @tparam Matrix self The matrix to use
    -- @treturn Matrix The resulting cofactor matrix
    -- @usage m:cofactor()
    cofactor = function(self)
        if self.rows ~= self.columns then
            error("Must be a square matrix to calculate cofactor matrix!")
        end

        return new(self.rows, self.columns, function(r, c)
            local sign = ((-1) ^ (r + c))
            local minor_det = self:minor(r, c):determinant()
            return sign * minor_det
        end)
    end,

    --- Computes the adjugate (adjoint) matrix.
    --
    -- @tparam Matrix self The matrix to use
    -- @treturn Matrix The resulting adjugate matrix
    -- @usage m:adjugate()
    adjugate = function(self)
        if self.rows ~= self.columns then
            error("Must be a square matrix to calculate adjugate!")
        end

        return self:cofactor():transpose()
    end,

    --- Computes the inverse of a square matrix.
    --
    -- @tparam Matrix self The matrix to invert
    -- @treturn Matrix The resulting inverse matrix
    -- @usage m:inverse()
    inverse = function(self)
        if self.rows ~= self.columns then
            error("Must be a square matrix to calculate inverse!")
        end

        local det = self:determinant()
        if det == 0 then
            error("Matrix is singular (determinant is zero) - no inverse exists!")
        end

        if self.rows == 1 then
            return from2DArray({{1 / self[1][1]}})
        end

        local adj = self:adjugate()
        return adj / det
    end,

    --- Computes the trace (sum of diagonal elements) of a square matrix.
    --
    -- @tparam Matrix self The matrix to use
    -- @treturn number The trace value
    -- @usage m:trace()
    trace = function(self)
        if self.rows ~= self.columns then
            error("Must be a square matrix to calculate trace!")
        end
        local sum = 0
        for i = 1, self.rows do
            sum = sum + self[i][i]
        end
        return sum
    end,

    --- Computes the rank of the matrix using row reduction.
    --
    -- @tparam Matrix self The matrix to use
    -- @treturn number The rank (number of linearly independent rows)
    -- @usage m:rank()
    rank = function(self)
        local m = {}
        for r = 1, self.rows do
            m[r] = {}
            for c = 1, self.columns do
                m[r][c] = self[r][c]
            end
        end

        local rank = 0
        local row = 1

        for col = 1, self.columns do
            local pivot_row = nil
            for r = row, self.rows do
                if math.abs(m[r][col]) > 1e-10 then
                    pivot_row = r
                    break
                end
            end

            if pivot_row then
                m[row], m[pivot_row] = m[pivot_row], m[row]

                for r = row + 1, self.rows do
                    if math.abs(m[r][col]) > 1e-10 then
                        local factor = m[r][col] / m[row][col]
                        for c = col, self.columns do
                            m[r][c] = m[r][c] - factor * m[row][c]
                        end
                    end
                end

                rank = rank + 1
                row = row + 1

                if row > self.rows then
                    break
                end
            end
        end

        return rank
    end,

    --- Computes the Frobenius norm (square root of sum of squared elements).
    --
    -- @tparam Matrix self The matrix to measure
    -- @treturn number The Frobenius norm
    -- @usage m:frobeniusNorm()
    frobeniusNorm = function(self)
        local sum = 0
        for r = 1, self.rows do
            for c = 1, self.columns do
                sum = sum + self[r][c] * self[r][c]
            end
        end
        return math.sqrt(sum)
    end,

    --- Computes the max norm (maximum absolute value of any element).
    --
    -- @tparam Matrix self The matrix to measure
    -- @treturn number The max norm
    -- @usage m:maxNorm()
    maxNorm = function(self)
        local max_val = 0
        for r = 1, self.rows do
            for c = 1, self.columns do
                max_val = math.max(max_val, math.abs(self[r][c]))
            end
        end
        return max_val
    end,

    --- Computes the Hadamard product (element-wise multiplication).
    --
    -- @tparam Matrix self The first matrix
    -- @tparam Matrix other The second matrix (must have same dimensions)
    -- @treturn Matrix The resulting matrix
    -- @usage m1:hadamardProduct(m2)
    hadamardProduct = function(self, other)
        expect(1, other, "table")
        if (getmetatable(other) or {}).__name ~= "matrix" then expect(1, other, "matrix") end

        if self.rows ~= other.rows or self.columns ~= other.columns then
            error("Matrices must have same dimensions for element-wise multiplication!")
        end

        return new(self.rows, self.columns, function(r, c) return self[r][c] * other[r][c] end)
    end,

    --- Computes element-wise division.
    --
    -- @tparam Matrix self The numerator matrix
    -- @tparam Matrix other The denominator matrix (must have same dimensions)
    -- @treturn Matrix The resulting matrix
    -- @usage m1:elementwiseDiv(m2)
    elementwiseDiv = function(self, other)
        expect(1, other, "table")
        if (getmetatable(other) or {}).__name ~= "matrix" then expect(1, other, "matrix") end

        if self.rows ~= other.rows or self.columns ~= other.columns then
            error("Matrices must have same dimensions for element-wise division!")
        end

        return self:hadamardProduct(new(other.rows, other.columns, function(r, c) return 1 / other[r][c] end))
    end,

    --- Checks if the matrix is symmetric.
    --
    -- @tparam Matrix self The matrix to test
    -- @treturn boolean True if the matrix equals its transpose
    -- @usage m:isSymmetric()
    isSymmetric = function(self)
        if self.rows ~= self.columns then
            return false
        end
        return self:equals(self:transpose())
    end,

    --- Checks if the matrix is diagonal.
    --
    -- @tparam Matrix self The matrix to test
    -- @treturn boolean True if all off-diagonal elements are zero
    -- @usage m:isDiagonal()
    isDiagonal = function(self)
        if self.rows ~= self.columns then
            return false
        end
        for r = 1, self.rows do
            for c = 1, self.columns do
                if r ~= c and math.abs(self[r][c]) > 1e-10 then
                    return false
                end
            end
        end
        return true
    end,

    --- Checks if the matrix is an identity matrix.
    --
    -- @tparam Matrix self The matrix to test
    -- @treturn boolean True if the matrix is diagonal with all ones on the diagonal
    -- @usage m:isIdentity()
    isIdentity = function(self)
        if not self:isDiagonal() then
            return false
        end
        return self:equals(identity(self.rows, self.columns))
    end,

    --- Returns a copy of this matrix, with the same data.
    --
    -- @tparam Matrix self The matrix to copy
    -- @treturn Matrix A new matrix with the same data as the original
    -- @usage m2 = m1:clone()
    clone = function(self)
        return new(self.rows, self.columns, function(r, c) return self[r][c] end)
    end,

    --- Performs LU decomposition using partial pivoting.
    --
    -- @tparam Matrix self The matrix to decompose
    -- @treturn Matrix L The lower triangular matrix
    -- @treturn Matrix U The upper triangular matrix
    -- @treturn table P The permutation array (indices of row swaps)
    -- @usage L, U, P = m:luDecomposition()
    luDecomposition = function(self)
        if self.rows ~= self.columns then
            error("Matrix must be square for LU decomposition!")
        end

        local n = self.rows
        local U = self:clone()
        local L = new(n, n, 0)
        local P = {}
        
        for i = 1, n do
            P[i] = i
            L[i][i] = 1
        end

        for col = 1, n do
            -- Find pivot
            local maxVal, maxRow = math.abs(U[col][col]), col
            for r = col + 1, n do
                if math.abs(U[r][col]) > maxVal then
                    maxVal = math.abs(U[r][col])
                    maxRow = r
                end
            end

            -- Swap rows in U and L
            if maxRow ~= col then
                U[col], U[maxRow] = U[maxRow], U[col]
                for c = 1, col - 1 do
                    L[col][c], L[maxRow][c] = L[maxRow][c], L[col][c]
                end
                P[col], P[maxRow] = P[maxRow], P[col]
            end

            if math.abs(U[col][col]) < 1e-10 then
                error("Matrix is singular or nearly singular!")
            end

            -- Elimination
            for r = col + 1, n do
                local factor = U[r][col] / U[col][col]
                L[r][col] = factor
                for c = col, n do
                    U[r][c] = U[r][c] - factor * U[col][c]
                end
            end
        end

        return L, U, P
    end,

    --- Converts a matrix to a 1D vector (flattened row-major order).
    --
    -- @tparam Matrix self The matrix to flatten
    -- @treturn table A 1D array of all elements in row-major order
    -- @usage v = m:flatten()
    flatten = function(self)
        local result = {}
        local idx = 1
        for r = 1, self.rows do
            for c = 1, self.columns do
                result[idx] = self[r][c]
                idx = idx + 1
            end
        end
        return result
    end,

    --- Reshapes the matrix to new dimensions.
    --
    -- @tparam Matrix self The matrix to reshape
    -- @tparam number rows New number of rows
    -- @tparam number columns New number of columns
    -- @treturn Matrix The reshaped matrix
    -- @usage m2 = m1:reshape(2, 6)
    reshape = function(self, rows, columns)
        expect(1, rows, "number")
        expect(2, columns, "number")

        if self.rows * self.columns ~= rows * columns then
            error("Cannot reshape: total elements must remain the same!")
        end

        local flat = self:flatten()
        return new(rows, columns, function(r, c) return flat[(r - 1) * columns + c] end)
    end,

    --- Extracts a submatrix.
    --
    -- @tparam Matrix self The matrix to extract from
    -- @tparam number r1 Starting row
    -- @tparam number r2 Ending row
    -- @tparam number c1 Starting column
    -- @tparam number c2 Ending column
    -- @treturn Matrix The submatrix
    -- @usage sub = m:submatrix(1, 2, 1, 2)
    submatrix = function(self, r1, r2, c1, c2)
        expect(1, r1, "number")
        expect(2, r2, "number")
        expect(3, c1, "number")
        expect(4, c2, "number")

        if r1 < 1 or r2 > self.rows or c1 < 1 or c2 > self.columns or r1 > r2 or c1 > c2 then
            error("Invalid submatrix bounds!")
        end

        return new(r2 - r1 + 1, c2 - c1 + 1, function(r, c) return self[r1 + r - 1][c1 + c - 1] end)
    end,

    --- Vertically stacks matrices (concatenates rows).
    --
    -- @tparam Matrix self First matrix
    -- @tparam Matrix other Second matrix
    -- @treturn Matrix The stacked matrix
    -- @usage m3 = m1:vstack(m2)
    vstack = function(self, other)
        expect(1, other, "table")
        if (getmetatable(other) or {}).__name ~= "matrix" then expect(1, other, "matrix") end

        if self.columns ~= other.columns then
            error("Matrices must have the same number of columns for vertical stacking!")
        end

        return new(self.rows + other.rows, self.columns, function(r, c)
            if r <= self.rows then
                return self[r][c]
            else
                return other[r - self.rows][c]
            end
        end)
    end,

    --- Horizontally stacks matrices (concatenates columns).
    --
    -- @tparam Matrix self First matrix
    -- @tparam Matrix other Second matrix
    -- @treturn Matrix The stacked matrix
    -- @usage m3 = m1:hstack(m2)
    hstack = function(self, other)
        expect(1, other, "table")
        if (getmetatable(other) or {}).__name ~= "matrix" then expect(1, other, "matrix") end

        if self.rows ~= other.rows then
            error("Matrices must have the same number of rows for horizontal stacking!")
        end

        return new(self.rows, self.columns + other.columns, function(r, c)
            if c <= self.columns then
                return self[r][c]
            else
                return other[r][c - self.columns]
            end
        end)
    end,

    --- Computes the 1-norm (maximum absolute column sum).
    --
    -- @tparam Matrix self The matrix
    -- @treturn number The 1-norm
    -- @usage norm = m:oneNorm()
    oneNorm = function(self)
        local max_col_sum = 0
        for c = 1, self.columns do
            local col_sum = 0
            for r = 1, self.rows do
                col_sum = col_sum + math.abs(self[r][c])
            end
            max_col_sum = math.max(max_col_sum, col_sum)
        end
        return max_col_sum
    end,

    --- Computes the 2-norm (spectral norm via power iteration).
    --
    -- @tparam Matrix self The matrix
    -- @treturn number The 2-norm
    -- @usage norm = m:twoNorm()
    twoNorm = function(self)
        local n = self.columns
        local v = new(n, 1, function() return math.random() end)
        v = v / v:frobeniusNorm()

        local prev_norm = 0
        for i = 1, 100 do
            local Av = self * v
            local norm = Av:frobeniusNorm()
            
            if math.abs(norm - prev_norm) < 1e-10 then
                return norm
            end
            
            v = Av / norm
            prev_norm = norm
        end
        return prev_norm
    end,

    --- Computes the infinity norm (maximum absolute row sum).
    --
    -- @tparam Matrix self The matrix
    -- @treturn number The infinity norm
    -- @usage norm = m:infinityNorm()
    infinityNorm = function(self)
        local max_row_sum = 0
        for r = 1, self.rows do
            local row_sum = 0
            for c = 1, self.columns do
                row_sum = row_sum + math.abs(self[r][c])
            end
            max_row_sum = math.max(max_row_sum, row_sum)
        end
        return max_row_sum
    end,

    --- Computes the condition number.
    --
    -- @tparam Matrix self The matrix
    -- @treturn number The condition number (>=1)
    -- @usage cond = m:conditionNumber()
    conditionNumber = function(self)
        if self.rows ~= self.columns then
            error("Condition number requires a square matrix!")
        end

        local norm_A = self:twoNorm()
        local det = self:determinant()
        
        if math.abs(det) < 1e-15 then
            return math.huge
        end

        local A_inv = self:inverse()
        local norm_A_inv = A_inv:twoNorm()
        
        return norm_A * norm_A_inv
    end
}

metatable = {
    __name = "matrix",
    __index = matrix,
    __add = matrix.add,
    __sub = matrix.sub,
    __mul = matrix.mul,
    __div = matrix.div,
    __unm = matrix.unm,
    __pow = matrix.pow,
    __len = matrix.length,
    __tostring = matrix.tostring,
    __eq = matrix.equals
}