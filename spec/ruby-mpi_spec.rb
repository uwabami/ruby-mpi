require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MPI" do
  before(:all) do
    MPI.Init()
  end
  after(:all) do
    MPI.Finalize()
  end

  it "should give version" do
    MPI.constants.should include("VERSION")
    MPI.constants.should include("SUBVERSION")
    MPI::VERSION.class.should eql(Fixnum)
    MPI::SUBVERSION.class.should eql(Fixnum)
  end

  it "should have Comm:WORLD" do
    MPI::Comm.constants.should include("WORLD")
    world = MPI::Comm::WORLD
    world.rank.class.should eql(Fixnum)
    world.size.class.should eql(Fixnum)
    world.size.should > 0
  end

  it "should send and receive String" do
    world = MPI::Comm::WORLD
    message = "Hello from #{world.rank}"
    tag = 0
    world.Send(message, 0, tag)
    if world.rank == 0
      world.size.times do |i|
        str = " "*30
        status = world.Recv(str, i, tag)
        status.source.should eql(i)
        status.tag.should eql(tag)
        status.error.should eq(MPI::SUCCESS)
        str.should match(/\AHello from #{i}+/)
      end
    end
  end

  it "should send and receive NArray" do
    world = MPI::Comm::WORLD
    tag = 0
    [NArray[1,2,3], NArray[3.0,2.0,1.0]].each do |ary0|
      ary0 = NArray[1,2,3]
      world.Send(ary0, 0, tag)
      if world.rank == 0
        world.size.times do |i|
          ary1 = NArray.new(ary0.typecode, ary0.total)
          status = world.Recv(ary1, i, tag)
          status.source.should eql(i)
          status.tag.should eql(tag)
          status.error.should eq(MPI::SUCCESS)
          ary1.should == ary0
        end
      end
    end
  end

  it "should send and receive without blocking" do
    world = MPI::Comm::WORLD
    message = "Hello from #{world.rank}"
    tag = 0
    request = world.Isend(message, 0, tag)
    status = request.Wait
    status.source.should eql(world.rank)
    status.tag.should eql(tag)
    if world.rank == 0
      world.size.times do |i|
        str = " "*30
        request = world.Irecv(str, i, tag)
        status = request.Wait
        status.source.should eql(i)
        status.tag.should eql(tag)
        str.should match(/\AHello from #{i}+/)
      end
    end
  end

  it "should gather data" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    root = 0
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = rank == root ? "?"*bufsize*size  : nil
    world.Gather(sendbuf, recvbuf, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s*bufsize}
      recvbuf.should eql(str)
    end
  end

  it "should gather data to all processes (allgather)" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = "?"*bufsize*size
    world.Allgather(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    recvbuf.should eql(str)
  end

  it "should broad cast data (bcast)" do
    world = MPI::Comm::WORLD
    rank = world.rank
    root = 0
    bufsize = 2
    if rank == root
      buffer = rank.to_s*bufsize
    else
      buffer = " "*bufsize
    end
    world.Bcast(buffer, root)
    buffer.should eql(root.to_s*bufsize)
  end

  it "should scatter data" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    root = 0
    bufsize = 2
    if rank == root
      sendbuf = ""
      size.times{|i| sendbuf << i.to_s*bufsize}
    else
      sendbuf = nil
    end
    recvbuf = " "*bufsize
    world.Scatter(sendbuf, recvbuf, root)
    recvbuf.should eql(rank.to_s*bufsize)
  end

  it "should send and recv data (sendrecv)" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    dest = rank-1
    dest = size-1 if dest < 0
    #dest = MPI::PROC_NULL if dest < 0
    source = rank+1
    source = 0 if source > size-1
    #source = MPI::PROC_NULL if source > size-1
    sendtag = rank
    recvtag = source
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = " "*bufsize
    world.Sendrecv(sendbuf, dest, sendtag, recvbuf, source, recvtag);
    if source != MPI::PROC_NULL
      recvbuf.should  eql(source.to_s*bufsize)
    end
  end

  it "should change data between each others (alltoall)" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize*size
    recvbuf = "?"*bufsize*size
    world.Alltoall(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    recvbuf.should eql(str)
  end

  it "should reduce data" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    root = 0
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = rank == root ? NArray.new(sendbuf.typecode,bufsize) : nil
    world.Reduce(sendbuf, recvbuf, MPI::Op::SUM, root)
    if rank == root
      ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
      recvbuf.should == ary
    end
  end

  it "should reduce data and send to all processes (allreduce)" do
    world = MPI::Comm::WORLD
    rank = world.rank
    size = world.size
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,bufsize)
    world.Allreduce(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
    recvbuf.should == ary
  end

  it "should not raise exception in calling barrier" do
    world = MPI::Comm::WORLD
    world.Barrier
  end


  it "shoud raise exeption" do
    world = MPI::Comm::WORLD
    lambda{ world.Send("", -1, 0) }.should raise_error(MPI::ERR::RANK)
    lambda{ world.Send("", world.size+1, 0) }.should raise_error(MPI::ERR::RANK)
    world.Errhandler.should eql(MPI::Errhandler::ERRORS_RETURN)
  end

end
