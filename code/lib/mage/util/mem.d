module mage.util.mem;
import std.algorithm : max;

auto KiB(size_t i) { return i * 1024; }
auto MiB(size_t i) { return KiB(i) * 1024; }
auto GiB(size_t i) { return MiB(i) * 1024; }
auto TiB(size_t i) { return GiB(i) * 1024; }

struct Mallocator
{
  @disable this(this);
}

static shared Mallocator mallocator;

@trusted void[] allocate(shared ref Mallocator a, size_t size)
{
  import core.stdc.stdlib : malloc;
  if(!size) {
    return null;
  }
  auto ptr = malloc(size);
  return ptr ? ptr[0..size] : null;
}

@system void deallocate(shared ref Mallocator a, void[] mem)
{
  import core.stdc.stdlib : free;
  free(mem.ptr);
}

unittest {
  auto p = mallocator.allocate(32);
  scope(exit) mallocator.deallocate(p);
  assert(p !is null);
  assert(mallocator.allocate(0) is null);
}

auto allocate(T, A, Args...)(ref A allocator, Args args)
{
  import std.conv : emplace;
  return emplace!(T, Args)(allocator.allocate(T.sizeof), args);
}

void deallocate(A, T)(ref A allocator, T instance)
{
  allocator.deallocate(cast(void[])(&instance)[0..T.sizeof]);
}

unittest {
  struct X { int a = 42; int b = 1337; }
  auto px = mallocator.allocate!X;
  scope(exit) mallocator.deallocate(px);
  assert(px.a == 42);
  assert(px.b == 1337);
}

struct Block(size_t N = 4.KiB)
{
  void[N] mem;
  size_t ap = 0; // Allocation pointer.
}

void[] allocate(size_t N)(ref Block!N b, size_t size)
{
  if(!size || b.ap + size > N) {
    return null;
  }
  auto mem = b.mem[b.ap .. b.ap + size];
  b.ap += size;
  return mem;
}

void deallocate(size_t N)(ref Block!N b)
{
  b.ap = 0;
}

unittest {
  auto block = Block!(16)();
  auto m1 = block.allocate(8);
  assert(m1 !is null);
  auto m2 = block.allocate(4);
  assert(m1 !is null);
  auto m3 = block.allocate(8);
  assert(m1 !is null);
}

unittest {
  auto block = Block!(16)();
  struct S { int a = 42; int b = 1337; }
  import mage;
  auto ps = block.allocate!S();
  assert(ps.a == 42);
  assert(ps.b == 1337);
  ps = block.allocate!S(1, 2);
  assert(ps.a == 1);
  assert(ps.b == 2);
}
