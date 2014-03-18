require_relative 'prime_field'
require_relative 'point'

module ECDSA
  class Group
    attr_reader :name

    attr_reader :generator

    attr_reader :order

    attr_reader :param_a

    attr_reader :param_b

    attr_reader :field

    # These parameters are defined in http://www.secg.org/collateral/sec2_final.pdf
    #
    # - +p+: A prime number that defines the field used.  The field will be F_p.
    # - +a+: The a parameter in the curve equation (y^2 = x^3 + ax + b).
    # - +b+: The b parameter in the curve equation.
    # - +g+: The base point as an octet string.
    # - +n+: The order of g.
    # - +h+: The cofactor.
    def initialize(opts)
      @opts = opts

      @name = opts.fetch(:name) { '%#x' % object_id }
      @field = PrimeField.new(opts[:p])
      @param_a = opts[:a]
      @param_b = opts[:b]
      @generator = new_point(@opts[:g])
      @order = opts[:n]
      @cofactor = opts[:h]

      @param_a.is_a?(Integer) or raise ArgumentError, 'Invalid a.'
      @param_b.is_a?(Integer) or raise ArgumentError, 'Invalid b.'

      @param_a = field.mod @param_a
      @param_b = field.mod @param_b
    end

    # TODO: allow generating points from:
    #  compressed octet strings
    #  [x, y]  (public key numbers)
    #  a       (private key number)
    def new_point(p)
      case p
      when :infinity
        infinity_point
      when Array
        x, y = p
        Point.new(self, x, y)
        # TODO: resolve this inconsistency; Point.new takes two coords but group.new_point takes an array of points
      when Integer
        generator.multiply_by_scalar(p)
      else
        raise ArgumentError, "Invalid point specifier #{p.inspect}."
      end
    end

    def infinity_point
      @infinity_point ||= Point.new(self, :infinity)
    end

    # The number of bits that it takes to represent a member of the field.
    # Log base 2 of the prime p, rounded up.
    def bit_length
      @bit_length ||= ECDSA.bit_length(field.prime)
    end

    def byte_length
      @byte_length ||= ECDSA.byte_length(field.prime)
    end

    # Verify that the point is a solution to the curve's defining equation.
    def include?(point)
      raise 'Group mismatch.' if point.group != self
      point.infinity? or point_satisfies_equation?(point)
    end

    # You should probably use include? instead of this.
    def point_satisfies_equation?(point)
      field.mod(point.y * point.y) == equation_right_hand_side(point.x)
    end

    def equation_right_hand_side(x)
      field.mod(x * x * x + param_a * x + param_b)
    end

    def solve_for_y(x)
      field.square_roots equation_right_hand_side x
    end

    def inspect
      "#<#{self.class}:#{name}>"
    end

    def to_s
      inspect
    end

    NAMES = %w(
      Secp112r1
      Secp112r2
      Secp128r1
      Secp128r2
      Secp160k1
      Secp160r1
      Secp160r2
      Secp192k1
      Secp192r1
      Secp224k1
      Secp224r1
      Secp256k1
      Secp256r1
      Secp384r1
      Secp521r1
      Nistp192
      Nistp224
      Nistp256
      Nistp384
      Nistp521
    )

    NAMES.each do |name|
      autoload name, 'ecdsa/group/' + name.downcase
    end
  end
end
