const std = @import("std");

const Instruction = @import("instruction.zig").Instruction;
const VirtualMachine = @import("VirtualMachine.zig");

pub fn main() !void {
    const ins_main: []const Instruction = &.{
        .{ .move_immediate = .{ .destination = 1, .value = 1 } }, // MOV %1, 1
        .{ .move = .{ .destination = 0, .source = 1 } }, // MOV %0, %1
        .{ .call = .{ .closure_pc = 8, .stack_size = 1, .destination = 1 } },
        .{ .move = .{ .destination = 2, .source = 1 } },
        .{ .call = .{ .closure_pc = 10, .stack_size = 1, .destination = 1 } },
        .{ .increment = .{ .destination = 0 } },
        .{ .add = .{ .destination = 0, .source = 1 } },
        .{ .@"return" = {} },
    };

    const ins_static_int: []const Instruction = &.{
        .{ .move_immediate = .{ .destination = 0, .value = 420 } },
        .{ .@"return" = {} },
    };

    const ins_increment_two_steps: []const Instruction = &.{
        .{ .add_immediate = .{ .destination = 0, .value = 2 } },
        .{ .@"return" = {} },
    };

    const instructions: []const Instruction = ins_main ++ ins_static_int ++ ins_increment_two_steps;

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    var vm = try VirtualMachine.init(gpa, instructions);
    const res = try vm.execute(0, 2);

    std.debug.print("vm completed with result: {}\n", .{res});
}
