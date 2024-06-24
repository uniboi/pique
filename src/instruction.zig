const VirtualMachine = @import("VirtualMachine.zig");
const RegisterIndex = VirtualMachine.RegisterIndex;
const Register = VirtualMachine.Register;

pub const Instruction = union(enum) {
    pub const Return = void;
    pub const Call = struct { closure_pc: usize, stack_size: RegisterIndex, destination: RegisterIndex };

    pub const MoveImmediate = struct { destination: RegisterIndex, value: Register };
    pub const Move = struct { destination: RegisterIndex, source: RegisterIndex };

    pub const Add = struct { destination: RegisterIndex, source: RegisterIndex };
    pub const AddImmediate = struct { destination: RegisterIndex, value: Register };

    pub const Increment = struct { destination: RegisterIndex };
    pub const Decrement = struct { destination: RegisterIndex };

    /// Write value of register 0 into the destination register of the previous stack frame
    @"return": Return,

    /// Call a subroutine.
    /// Parameters are written into the registers 0-n with previous move instructions
    call: Call,

    /// Copy the value of `source` into `destination`.
    /// This is not restricted to registers of the current frame.
    move: Move,
    /// Copy `value` into `destination`.
    /// This is not restricted to registers of the current frame.
    move_immediate: MoveImmediate,

    /// Add `source` to `destination`
    add: Add,
    /// Add `value` to `destination`
    add_immediate: AddImmediate,

    increment: Increment,
    decrement: Decrement,
};
