--- A basic quaternion type and some common quaternion operations. This may be useful
-- when working with rotation in regards to physics (such as those from the
-- Ship API provided by CC: VS).
--
-- An introduction to quaternions can be found on [Wikipedia][wiki].
--
-- [wiki]: https://en.wikipedia.org/wiki/Quaternion
--
-- Special thanks to getItemFromBlock and Shlomo for sharing their own quaternion handling code.
--
-- If you are interested in using [CCSharp][ccsharp], here is the compatible [Quaternion.cs][ccsharp-quaternion] file.
--
-- [ccsharp]: https://github.com/monkeymanboy/CCSharp
-- [ccsharp-quaternion]: https://github.com/monkeymanboy/CCSharp/blob/master/src/CCSharp/AdvancedMath/Quaternion.cs
--
-- @module quaternion
-- @author TechTastic
-- @author getItemFromBlock

local expect = dofile("rom/modules/main/cc/expect.lua").expect
local metatable

--- Constructors
--
-- @section Constructors

--- Constructs a new quaternion from a vector and a w parameter. Similarly to fromComponents, this method will not produce a normalized quaternion.
--
-- @tparam Vector vec imaginary component of the vector, stored in a vector. Uses [Vector](https://tweaked.cc/module/vector.html) type
-- @tparam number w Real component of the quaternion
-- @treturn The quaternion made from the given arguments
-- @usage q = quaternion.new(vec, w)
-- @export
function new(vec, w)
    expect(1, vec, "table", "nil")
    if type(vec) == "table" and (getmetatable(vec) or {}).__name ~= "vector" then expect(1, vec, "vector", "nil") end
    expect(2, w, "number", "nil")

	return setmetatable({
        v = vec or vector.new(),
        a = tonumber(w) or 1,
    }, metatable)
end

--- Constructs a new quaternion from the provided axis - angle parameters. The resulting quaternion is already normalized.
--
-- @tparam Vector axis Rotation axis that will be used for the quaternion. The axis does not need to be normalized. Uses [Vector](https://tweaked.cc/module/vector.html) type
-- @tparam number angle Angle in radians of the rotation
-- @treturn The quaternion representing the rotation described by the axis angle parameters
-- @usage q = quaternion.fromAxisAngle(axis, angle)
-- @export
function fromAxisAngle(axis, angle)
    expect(1, axis, "table", "nil")
    if type(axis) == "table" and (getmetatable(axis) or {}).__name ~= "vector" then expect(1, axis, "vector", "nil") end
    expect(2, angle, "number", "nil")

    if not axis then
        axis = vector.new()
    else
        axis = axis:normalize()
    end
    angle = angle or 0
    local h_angle = angle / 2
    return new(axis * math.sin(h_angle), math.cos(h_angle))
end

--- Constructs a new quaternion using the provided pitch, yaw and roll. Uses the YXZ reference frame
--
-- @tparam number pitch Pitch in radians
-- @tparam number yaw Yaw in radians
-- @tparam number roll Roll in radians
-- @treturn the quaternion made from the provided euler angles
-- @usage q = quaternion.fromEuler(pitch, yaw, roll)
-- @export
function fromEuler(pitch, yaw, roll)
    expect(1, pitch, "number", "nil")
    expect(2, yaw, "number", "nil")
    expect(3, roll, "number", "nil")

    pitch = pitch or 0
    yaw = yaw or 0
    roll = roll or 0
    return fromAxisAngle(vector.new(0, 1, 0), yaw) * fromAxisAngle(vector.new(1, 0, 0), pitch) * fromAxisAngle(vector.new(0, 0, 1), roll)
end

--- Constructs a new quaternion using the four provided components. This will not normalize the quaternion unlike other functions, so use at your own risks.
--
-- @tparam number x
-- @tparam number y
-- @tparam number z
-- @tparam number w
-- @treturn the quaternion made from the provided components
-- @usage q = quaternion.fromComponents(x, y, z, w)
-- @export
function fromComponents(x, y, z, w)
    expect(1, x, "number", "nil")
    expect(2, y, "number", "nil")
    expect(3, z, "number", "nil")
    expect(4, w, "number", "nil")

    x = x or 0
    y = y or 0
    z = z or 0
    return new(vector.new(x, y, z), w)
end

--- Constructs a new quaternion from a 3x3 rotation matrix or 4x4 transformation matrix.
--
--
-- @tparam Matrix m The rotation matrix to convert (3x3 or 4x4)
-- @treturn Quaternion The quaternion representing the same rotation
--      Note: For 4x4 matrices, only the upper-left 3x3 rotation portion is used
-- @usage q = quaternion.fromMatrix(m)
-- @export
-- @see matrix
function fromMatrix(m)
    if not matrix then
        error("Matrix API is not loaded!")
    end
    if getmetatable(m).__name ~= "matrix" then expect(1, m, "matrix") end
    
    if (m.rows ~= 3 or m.columns ~= 3) and (m.rows ~= 4 or m.columns ~= 4) then
        error("Matrix must be 3x3 or 4x4!")
    end
    
    if m.rows == 4 then
        m = m:minor(4, 4)
    end
    
    local trace = m:trace()
    
    local w, x, y, z
    
    if trace > 0 then
        local s = math.sqrt(trace + 1.0) * 2
        w = 0.25 * s
        x = (m[3][2] - m[2][3]) / s
        y = (m[1][3] - m[3][1]) / s
        z = (m[2][1] - m[1][2]) / s
    elseif m[1][1] > m[2][2] and m[1][1] > m[3][3] then
        local s = math.sqrt(1.0 + m[1][1] - m[2][2] - m[3][3]) * 2
        w = (m[3][2] - m[2][3]) / s
        x = 0.25 * s
        y = (m[1][2] + m[2][1]) / s
        z = (m[1][3] + m[3][1]) / s
    elseif m[2][2] > m[3][3] then
        local s = math.sqrt(1.0 + m[2][2] - m[1][1] - m[3][3]) * 2
        w = (m[1][3] - m[3][1]) / s
        x = (m[1][2] + m[2][1]) / s
        y = 0.25 * s
        z = (m[2][3] + m[3][2]) / s
    else
        local s = math.sqrt(1.0 + m[3][3] - m[1][1] - m[2][2]) * 2
        w = (m[2][1] - m[1][2]) / s
        x = (m[1][3] + m[3][1]) / s
        y = (m[2][3] + m[3][2]) / s
        z = 0.25 * s
    end
    
    return fromComponents(x, y, z, w)
end

function fromShip()
    error("This method is no longer required as of CC: VS 0.4.0, as the Ship API now provides quaternions directly.")
end

--- Constructs a new identity quaternion, representing an empty rotation.
--
-- @treturn an empty identity quaternion
-- @usage q = quaternion.identity()
-- @export
function identity()
    return new()
end

--- A quaternion, with imaginary component `v` and real component `a`.
--
-- This is suitable for representing rotation.
--
-- @type Quaternion
local quaternion = {
    --- The imaginary component of the quaternion, stored in a [Vector](https://tweaked.cc/module/vector.html).
    -- @field v
    -- @tparam Vector v

    --- The real component of the quaternion.
    -- @field a
    -- @tparam number a

    --- Adds two quaternions together. The resulting quaternion will not be normalized. If you want to add rotations together, use the mul function instead.
    --
    -- @tparam Quaternion self The first quaternion to add
    -- @tparam Quaternion other The second quaternion to add
    -- @treturn Quaternion The resulting quaternion
    -- @usage q1:add(q2)
    -- @usage q1 + q2
    add = function(self, other)
        expect(1, self, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(1, self, "quaternion") end
        expect(2, other, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(2, other, "quaternion") end

        return quaternion.new(
            self.v:add(other.v),
            self.a + other.a
        )
    end,

    --- Subtracts two quaternions together. The resulting quaternion will not be normalized.
    --
    -- @tparam Quaternion self The first quaternion to subtract from
    -- @tparam Quaternion other The second quaternion to subtract
    -- @treturn Quaternion The resulting quaternion
    -- @usage q1:sub(q2)
    -- @usage q1 - q2
    sub = function(self, other)
        expect(1, self, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(1, self, "quaternion") end
        expect(2, other, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(2, other, "quaternion") end

        return quaternion.new(
            self.v:sub(other.v),
            self.a - other.a
        )
    end,

    --- Multiplies a quaternion by a scalar value, another quaternion, or a [Vector](https://tweaked.cc/module/vector.html).
    --
    -- @tparam Quaternion self The quaternion to multiply
    -- @tparam number|Quaternion|Vector other The scalar value, quaternion, or vector to multiply with
    -- @treturn Quaternion|Vector The resulting quaternion or rotated vector
    --      Note: If using a quaternion value, the resuulting quaternion will be the "addition" of the two rotations
    --      Note: If using a vector value, will rotate the vector by the quaternion
    --      Note: If using a scalar value, the resulting quaternion will not be normalized
    -- @usage q:mul(3)
    -- @usage q * 3
    -- @usage q1:mul(q2)
    -- @usage q1 * q2
    -- @usage q:mul(v)
    -- @usage q * v
    mul = function(self, other)
        expect(1, self, "table", "number")
        if type(self) == "table" and (getmetatable(self) or {}).__name ~= "quaternion" and (getmetatable(self) or {}).__name ~= "vector" then expect(1, self, "quaternion", "vector", "number") end
        expect(2, other, "table", "number")
        if type(other) == "table" and (getmetatable(other) or {}).__name ~= "quaternion" and (getmetatable(other) or {}).__name ~= "vector" then expect(2, other, "quaternion", "vector", "number") end

        if type(self) == "number" or (getmetatable(self) or {}).__name == "vector" then
            return other * self
        end

        if type(other) == "table" then
            if getmetatable(other).__name == "quaternion" then
                -- Quaternion * Quaternion
                return quaternion.new(
                    other.v * self.a + self.v * other.a + self.v:cross(other.v),
                    self.a * other.a + -(self.v:dot(other.v))
                ):normalize()
            elseif getmetatable(other).__name == "vector" then
                -- Quaternion * Vector
                m_q = quaternion.new(other, 0)
                return (self * m_q * self:conjugate()).v
            end
        elseif type(other) == "number" then
            -- Quaternion * Scalar
            return quaternion.new(
                self.v * other,
                self.a * other
            )
        end

        error("Invalid Argument! Takes a scalar value, a quaternion, or a vector.")
    end,

    --- Divides a quaternion by a scalar or another quaternion.
    --
    -- @tparam Quaternion self The quaternion to divide
    -- @tparam Quaternion|number other The quaternion or scalar number to divide with
    -- @treturn Quaternion The resulting quaternion
    --      Note: If using a scalar value, the resulting quaternion will not be normalized
    -- @usage q1:div(q2)
    -- @usage q1 / q2
    -- @usage q:div(2)
    -- @usage q / 2
    div = function(self, other)
        expect(1, self, "table", "number")
        if type(self) == "table" and (getmetatable(self) or {}).__name ~= "quaternion" then expect(1, self, "quaternion", "number") end
        expect(2, other, "table", "number")
        if type(self) == "table" and (getmetatable(other) or {}).__name ~= "quaternion" then expect(2, other, "quaternion", "number") end

        if type(self) == "number" then
            return other * (1 / self)
        end

        if type(other) == "table" then
            return self * other:inverse()
        end
        if type(other) == "number" then
            return self * (1 / other)
        end
        error("Invalid Argument! Takes a scalar value or a quaternion.")
    end,

    --- Negates a quaternion.
    --
    -- @tparam Quaternion self The quaternion to negate
    -- @treturn Quaternion The resulting negated quaternion
    -- @usage q:unm()
    -- @usage -q
    unm = function(self)
        return self * -1
    end,

    --- Creates a string representation of the quaternion in the form of w + xi + yj + zk.
    --
    -- @tparam Quaternion self The quaternion to stringify
    -- @treturn string The resulting string
    -- @usage q:tostring()
    -- @usage q .. ""
    tostring = function(self)
        local str = tostring(self.a)
        if (self.v.x >= 0) then
            str = str .. " + "
        else
            str = str .. " - "
        end
        str = str .. tostring(math.abs(self.v.x)) .. "i"
        if (self.v.y >= 0) then
            str = str .. " + "
        else
            str = str .. " - "
        end
        str = str .. tostring(math.abs(self.v.y)) .. "j"
        if (self.v.z >= 0) then
            str = str .. " + "
        else
            str = str .. " - "
        end
        return str .. tostring(math.abs(self.v.z)) .. "k"
    end,

    --- Determines if the given quaternions are equal.
    --
    -- @tparam Quaternion self The first quaternion to test
    -- @tparam Quaternion other The other quaternion to test against
    -- @treturn boolean The result of the test, true if the quaternions are equals
    -- @usage q1:equals(q2)
    -- @usage q1 == q2
    equals = function(self, other)
        expect(1, self, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(1, self, "quaternion") end
        expect(2, other, "table")
        if (getmetatable(other) or {}).__name ~= "quaternion" then expect(2, other, "quaternion") end

        return self.v == other.v and self.a == other.a
    end,

    --- Finds the conjugate of the quaternion.
    --
    -- @tparam Quaternion self The quaternion to use
    -- @treturn Quaternion The resulting conjugate
    -- @usage q:conjugate()
	conjugate = function(self)
		return quaternion.new(-self.v, self.a)
	end,

    --- Normalizes the quaternion.
    --
    -- @tparam Quaternion self The quaternion to use
    -- @treturn Quaternion The resulting normalized quaternion
    -- @usage q:normalize()
	normalize = function(self)
		local l = #self
		return quaternion.new(self.v / l, self.a / l)
	end,

    --- Computes the inverse of the quaternion.
    --
    -- @tparam Quaternion self The quaternion to use
    -- @treturn Quaternion The resulting inverse quaternion
    -- @usage q:inverse()
	inverse = function(self)
		if (#self) ^ 2 < 1e-5 then
			return self
		end
		return self:conjugate()/(self.a ^ 2 + self.v.x ^ 2 + self.v.y ^ 2 + self.v.z ^ 2)
	end,

    --- Performs Spherical Linear Interpolation (SLerp) between the two given quaternions and alpha value.
    --
    -- @tparam Quaternion self The origin quaternion
    -- @tparam Quaternion other The other quaternion
    -- @tparam number alpha The lerp ratio to use, expected to be in the 0..1 range
    -- @treturn Quaternion The resulting quaternion
    -- @usage q1:slerp(q2, alpha)
	slerp = function(self, other, alpha)
        expect(1, self, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(1, self, "quaternion") end
        expect(2, other, "table")
        if (getmetatable(self) or {}).__name ~= "quaternion" then expect(2, other, "quaternion") end
        expect(3, alpha, "number")

        local a = self:copy()
        local b = other:copy()
        local cos_half_theta = a.a * b.a + a.v.x * b.v.x + a.v.y * b.v.y + a.v.z * b.v.z

        if math.abs(cos_half_theta) >= 1 then
            return a
        end

        if cos_half_theta < 0 then
            b = -b
            cos_half_theta = -cos_half_theta
        end

        local half_theta = math.acos(cos_half_theta)
        local sin_half_theta = math.sqrt(1 - cos_half_theta * cos_half_theta)
        if sin_half_theta < 0.0001 then
            return a * 0.5 + b * 0.5
        end
        local ratio_a = math.sin((1 - alpha) * half_theta) / sin_half_theta
        local ratio_b = math.sin(alpha * half_theta) / sin_half_theta
        return a * ratio_a + b * ratio_b
    end,

    --- Gets the angle of the rotation defined by the given quaternion.
    --
    -- @tparam Quaternion self The quaternion to use as a rotation source
    -- @treturn number The resulting angle in radians
    -- @usage q:getAngle()
    getAngle = function(self)
        self = self:normalize()
        return 2 * math.acos(self.a)
    end,

    --- Gets the normalized axis of rotation corresponding to the rotation defined by the given quaternion. Uses [Vector](https://tweaked.cc/module/vector.html) type.
    --
    -- @tparam Quaternion self The quaternion to use as a rotation source
    -- @treturn Vector The resulting axis
    -- @usage q:getAxis()
    getAxis = function(self)
        self = self:normalize()
        local factor = math.sqrt(1 - self.a * self.a)
        if factor == 0 then
            factor = 1
        end
        return self.v / factor
    end,

    --- Gets the pitch, yaw and roll euler angles from the given quaternion. Uses the YXZ reference frame
    --
    -- @tparam Quaternion self The quaternion.
    -- @treturn number Pitch in radians
    -- @treturn number Yaw in radians
    -- @treturn number Roll in radians
    -- @usage q:toEuler()
    toEuler = function(self)
        self = self:normalize()

        local pitch, yaw, roll

        local a = self.a
        local b = self.v.x
        local c = self.v.y
        local d = self.v.z

        local singularity = 2 * (c * d - b * a)

        if singularity > 0.9999 then
            pitch = -math.pi / 2
            yaw = math.atan2(-2 * (b * c - d * a), 2 * (a * a + b * b) - 1)
            roll = 0
        elseif singularity < -0.9999 then
            pitch = math.pi / 2
            yaw = -math.atan2(-2 * (b * c - d * a), 2 * (a * a + b * b) - 1)
            roll = 0
        else
            pitch = math.asin(-singularity)
            yaw = math.atan2(2 * (b * d + c * a), 2 * (a * a + d * d) - 1)
            roll = math.atan2(2 * (b * c + d * a), 2 * (a * a + c * c) - 1)
        end

        return pitch, yaw, roll
    end,

    --- Computes the length of the quaternion.
    --
    -- @tparam Quaternion self The quaternion to measure
    -- @treturn number The length of the quaternion
    -- @usage q:length()
    -- @usage #q
	length = function(self)
		return math.sqrt(self.a ^ 2 + self.v.x ^ 2 + self.v.y ^ 2 + self.v.z ^ 2)
	end,

    --- Checks if any component of the quaternion is NaN.
    --
    -- @tparam Quaternion self The quaternion to test
    -- @treturn boolean True if the quaternion has at least one component set to NaN
    -- @usage q:isNan()
	isNan = function(self)
        return self.a ~= self.a or self.v.x ~= self.v.x or self.v.y ~= self.v.y or self.v.z ~= self.v.z
    end,

    --- Check if any component of the quaternion is infinite.
    --
    -- @tparam Quaternion self The quaternion to test
    -- @treturn boolean True if the quaternion has at least one infinite component
    -- @usage q:isInf()
    isInf = function(self)
        local inf = 1/0
        return math.abs(self.a) == inf or math.abs(self.v.x) == inf or math.abs(self.v.y) == inf or math.abs(self.v.z) == inf
    end,

    --- Returns a copy of this quaternion, with the same data.
    --
    -- @treturn a new quaternion with the same data as the original
    -- @usage b = a:copy()
    copy = function(self)
        return quaternion.new(vector.new(self.v.x, self.v.y, self.v.z), self.a)
    end
}

metatable = {
    __name = "quaternion",
    __index = quaternion,
    __add = quaternion.add,
    __sub = quaternion.sub,
    __mul = quaternion.mul,
    __div = quaternion.div,
    __unm = quaternion.unm,
    __len = quaternion.length,
    __tostring = quaternion.tostring,
    __eq = quaternion.equals,
}