module mage.log;
import mage;

import io = std.stdio;

struct Log
{
  struct Block
  {
    string message;
    int indentation;
    bool isPrinted = false;

    @disable this();

    this(Args...)(string message, Args fmtargs)
    {
      static if(Args.length) {
        this.message = message.format(fmtargs);
      }
      else {
        this.message = message;
      }
      this.indentation = blocks.length;
      blocks ~= &this;
    }

    ~this()
    {
      assert(blocks[$-1] == &this, "Popping log Blocks in wrong order.");
      blocks.length--;
      if(this.isPrinted) {
        print("<<<| ", "<<< ", "");
      }
    }

    void print(string linePrefix, string messagePrefix, string messageSuffix)
    {
      io.writef("%-*s", 2 * this.indentation + linePrefix.length, linePrefix);
      io.writefln("%s%s%s", messagePrefix, this.message, messageSuffix);
      this.isPrinted = true;
    }
  }

static:
  Block*[] blocks;

  void info   (Args...)(string fmt, Args fmtargs) { doLog!"Ifo| "(fmt, fmtargs); }
  void trace  (Args...)(string fmt, Args fmtargs) { doLog!"Trc| "(fmt, fmtargs); }
  void error  (Args...)(string fmt, Args fmtargs) { doLog!"Err| "(fmt, fmtargs); }
  void warning(Args...)(string fmt, Args fmtargs) { doLog!"Wrn| "(fmt, fmtargs); }

  package void printBlocks()
  {
    foreach(block; blocks) {
      if(!block.isPrinted) {
        block.print(">>>| ", ">>> ", "");
        assert(block.isPrinted);
      }
    }
  }

  package void doLog(string prefix, Args...)(string message, Args fmtargs)
  {
    printBlocks();
    io.writef("%-*s", 2 * blocks.length + prefix.length, prefix);
    io.writefln(message, fmtargs);
  }
}

unittest
{
  Log.info("Hello testing world");
  with(Log.Block("Block 0"))
  {
    Log.info("Inner message");
    with(Log.Block("Block 1"))
    {
      Log.info("Going deeper...");
    }
    Log.info("Backing out again.");
  }
  Log.info("Back to the top-level");
}

shared static this() {
  // TODO Set some awesome default logger.
}
