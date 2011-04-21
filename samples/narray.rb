require "mpi"

MPI.Init


world = MPI::Comm::WORLD
rank = world.rank

if rank == 0
  (world.size-1).times do |i|
    a = NArray.float(2)
    world.Recv(a, i+1, 1)
    p a
  end
else
  world.Send(NArray[1.0,2], 0, 1)
end


MPI.Finalize
