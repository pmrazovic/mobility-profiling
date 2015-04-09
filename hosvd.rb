# HOSVD for 3rd-order tensor (e.g. user x location x time)

require "narray"
require 'numru/lapack'

def kronecker_product(a,b)
  result = NArray.float(a.shape[0]*b.shape[0],a.shape[1]*b.shape[1])
  (0..a.shape[0]-1).each do |j|
    (0..a.shape[1]-1).each do |i|
      result[j*b.shape[0]..(j*b.shape[0]+b.shape[0]-1),i*b.shape[1]..(i*b.shape[1]+b.shape[1]-1)] = a[j,i]*b
    end
  end
  return result
end

def unfold(tensor,axis)
  # NArray follows FORTRAN index ordering (I_2 (axis_2) x I_1 (axis_1) x I_3 (axis_3))

  dim = tensor.shape

  if axis == 0
    a_u = NArray.float(dim[0]*dim[2],dim[1])
    count = 0
    (0..dim[0]-1).each do |idx0|
      (0..dim[2]-1).each do |idx2|
        a_u[count,true] = tensor[idx0,true,idx2]
        count += 1
      end      
    end
  elsif axis == 1
    a_u = NArray.float(dim[1]*dim[2],dim[0])
    count = 0
    (0..dim[1]-1).each do |idx1|
      (0..dim[2]-1).each do |idx2|
        a_u[count,true] = tensor[true,idx1,idx2]
        count += 1
      end      
    end
  elsif axis == 2
    a_u = NArray.float(dim[0]*dim[1],dim[2])
    count = 0
    (0..dim[0]-1).each do |idx0|
      (0..dim[1]-1).each do |idx1|
        a_u[count,true] = tensor[idx0,idx1,true]
        count += 1
      end      
    end
  end

  return a_u
end

def fold(matrix,axis)
  # NArray follows FORTRAN index ordering (I_2 (axis_2) x I_1 (axis_1) x I_3 (axis_3))
end

def hosvd(tensor)
  mode_matrices = []
  n_mode_singular_values = []
  (0..2).each do |axis|
    s, u, vt, work, info, a = NumRu::Lapack.dgesvd( 'A', 'A', unfold(tensor,axis).transpose(1,0))
    mode_matrices << u.transpose(1,0)
    n_mode_singular_values << s
  end
  
  # number of principal components
  c1 = 0.5
  c2 = 0.5
  c3 = 0.5

  # c-dimensionally reduced mode matrices
  u1 = mode_matrices[0][0..(mode_matrices[0].shape[0]*c1).ceil,true]
  u2 = mode_matrices[1][0..(mode_matrices[1].shape[0]*c2).ceil,true]
  u3 = mode_matrices[2][0..(mode_matrices[2].shape[0]*c3).ceil,true]

  # core tensor unfolded along axis 0
  s_u = NMatrix.ref(u1).transpose(1,0)*NMatrix.ref(unfold(tensor,0)) * NMatrix.ref(kronecker_product(u2,u3))

  # checking results
  puts NMatrix.ref(unfold(tensor,0)).inspect
  puts (NMatrix.ref(u1)*s_u*NMatrix.ref(kronecker_product(u2,u3).transpose(1,0))).inspect

  return s_u
end


# example tensor
t = NArray[ [ [ 1.0, 2.0 ], 
              [ 1.0, 2.0 ], 
              [ 2.0, 4.0 ] ], 
            [ [ 1.0, 2.0 ], 
              [ -1.0, -2.0 ], 
              [ 0.0, 0.0 ] ], 
            [ [ 0.0, 0.0 ], 
              [ 2.0, 4.0 ], 
              [ 2.0, 4.0 ] ] ]
              

hosvd(t)