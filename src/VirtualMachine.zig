const std = @import("std");
const Instruction = @import("instruction.zig").Instruction;

const VirtualMachine = @This();

pub const RuntimeError = error{} || std.mem.Allocator.Error;

/// Register content
pub const Register = usize;

/// Index into the vm registers that is relative to the current stack frame's base register
pub const RegisterIndex = u8;

pub const StackFrame = struct {
    previous: ?*const StackFrame,
    /// pc where that the vm will return to when collapsing this frame
    origin_pc: usize,
    /// base register index for this frame
    base_register: usize,
    /// amount of owned registers
    stack_size: usize,
    /// register index where the returned value will be moved to
    destination: RegisterIndex,

    pub fn init(allocator: std.mem.Allocator, previous: ?*const StackFrame, origin_pc: usize, base_register: usize, stack_size: usize, destination: RegisterIndex) RuntimeError!*const StackFrame {
        var frame = try allocator.create(StackFrame);

        frame.previous = previous;
        frame.origin_pc = origin_pc;
        frame.base_register = base_register;
        frame.stack_size = stack_size;
        frame.destination = destination;

        return frame;
    }

    pub fn deinit(frame: *const StackFrame, allocator: std.mem.Allocator) void {
        allocator.destroy(frame);
    }

    pub fn registers(frame: StackFrame, vm: *const VirtualMachine) []Register {
        return vm.registers[frame.base_register .. frame.base_register + frame.stack_size];
    }
};

allocator: std.mem.Allocator,
pc: usize,
instructions: []const Instruction,
registers: []Register,

pub fn init(alloc: std.mem.Allocator, code: []const Instruction) std.mem.Allocator.Error!VirtualMachine {
    return .{
        .allocator = alloc,
        .pc = 0,
        .instructions = code,
        .registers = try alloc.alloc(Register, 256),
    };
}

pub fn deinit(vm: VirtualMachine) void {
    vm.allocator.free(vm.registers);
}

fn grow_stack(vm: *VirtualMachine) std.mem.Allocator.Error!void {
    const new_size = vm.registers.len + 256;
    const resized = vm.allocator.resize(vm.registers, new_size);

    if (!resized) {
        vm.registers = try vm.allocator.realloc(vm.registers, new_size);
    }
}

pub fn execute(vm: *VirtualMachine, origin_pc: usize, root_stack_size: RegisterIndex) RuntimeError!Register {
    std.debug.assert(root_stack_size < vm.registers.len);

    var frame = try StackFrame.init(vm.allocator, null, origin_pc, 0, root_stack_size, 0);
    var registers_in_use: usize = root_stack_size;

    // clean up all callstacks when an error occurs
    errdefer {
        var maybe_last_frame: ?*const StackFrame = frame;
        while (maybe_last_frame) |last_frame| {
            last_frame.deinit(vm.allocator);
            maybe_last_frame = last_frame.previous;
        }
    }

    vm.pc = origin_pc;

    while (true) {
        std.debug.assert(vm.pc < vm.instructions.len);

        // owned registers of the current frame
        const registers = frame.registers(vm);

        switch (vm.instructions[vm.pc]) {
            .move => |move| vm.registers[frame.base_register + move.destination] = registers[move.source],
            .move_immediate => |move| vm.registers[frame.base_register + move.destination] = move.value,

            .add => |add| registers[add.destination] += registers[add.source],
            .add_immediate => |add| registers[add.destination] += add.value,

            .increment => |inc| registers[inc.destination] += 1,
            .decrement => |dec| registers[dec.destination] -= 1,

            .call => |call| {
                std.debug.assert(vm.pc + 1 < vm.instructions.len);
                std.debug.assert(call.stack_size > 0);

                if (registers_in_use + call.stack_size >= vm.registers.len) {
                    try vm.grow_stack();
                }

                const next_frame = try StackFrame.init(vm.allocator, frame, vm.pc + 1, registers_in_use, call.stack_size, call.destination);
                frame = next_frame;
                vm.pc = call.closure_pc;

                registers_in_use += call.stack_size;
                continue;
            },
            .@"return" => {
                if (frame.previous) |previous_frame| {
                    previous_frame.registers(vm)[frame.destination] = registers[0];

                    registers_in_use -= frame.stack_size;
                    vm.pc = frame.origin_pc;

                    frame.deinit(vm.allocator);

                    frame = previous_frame;
                    continue;
                } else {
                    frame.deinit(vm.allocator);
                    return registers[0];
                }
            },
        }

        vm.pc += 1;
    }
}

test "move immediate" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 1);
}

test "move" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 1, .value = 1 } },
        .{ .move = .{ .destination = 0, .source = 1 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 2);
    try std.testing.expect(res == 1);
}

test "add immediate" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .add_immediate = .{ .destination = 0, .value = 8 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 9);
}

test "add" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .move_immediate = .{ .destination = 1, .value = 8 } },
        .{ .add = .{ .destination = 0, .source = 1 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 2);
    try std.testing.expect(res == 9);
}

test "increment" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .increment = .{ .destination = 0 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 2);
}

test "decrement" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .decrement = .{ .destination = 0 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 0);
}

test "call without parameters" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .call = .{ .closure_pc = 2, .stack_size = 1, .destination = 0 } },
        .{ .@"return" = {} },
        .{ .move_immediate = .{ .destination = 0, .value = 1 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 1);
}

test "call with parameters" {
    var vm = try VirtualMachine.init(std.testing.allocator, &.{
        .{ .move_immediate = .{ .destination = 1, .value = 1 } },
        .{ .call = .{ .closure_pc = 3, .stack_size = 1, .destination = 0 } },
        .{ .@"return" = {} },
        .{ .add_immediate = .{ .destination = 0, .value = 1 } },
        .{ .@"return" = {} },
    });
    defer vm.deinit();

    const res = try vm.execute(0, 1);
    try std.testing.expect(res == 2);
}
