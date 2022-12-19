import numpy as np

def method_prep(cmfs, w):
    """
    Computes two arrays in preparation for the lhtss method.

    Parameters
    ----------
    cmfs: nx3 array of color matching functions, where n
          is the number of wavelength bins (rows) of cmfs.
    w: an n-element vector of relative illuminant magnitudes,
          scaled arbitrarily.

    Returns
    -------
    d: nxn array of finite differencing constants.
    cmfs_w: nx3 array of illuminant-w-referenced CMFs.

    """

    # build tri-diagonal array of finite differencing constants
    d = np.eye(36, 36, k=-1)*-2 + np.eye(36, 36)*4 + np.eye(36, 36, k=1)*-2
    d[0, 0] = 2
    d[35, 35] = 2

    # build illuminant-w-referenced CMFs
    w1 = np.squeeze(w)
    w_norm = w1/(w1.dot(cmfs[:, 1]))
    cmfs_w = np.diag(w_norm).dot(cmfs)

    return d, cmfs_w