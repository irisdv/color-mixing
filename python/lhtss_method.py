import numpy as np
from scipy import linalg
import warnings
warnings.simplefilter("ignore")

def lhtss_method(d, cmfs_w, XYZ_w, max_iterations=100, tolerance=1e-8):
    """
    Least Hyperbolic Tangent Slope Squared (LHTSS) algorithm
    for generating a "reasonable" reflectance curve from a given sRGB color triplet
    developed by Scott Burns.

    Parameters
    ----------
    d: nxn array of finite differencing constants.
    cmfs_w: nx3 array of illuminant-w-referenced CMFs.
    XYZ_w: sRGB linear value converted to XYZ
    max_iterations: max number of iterations
    tolerance: function solution tolerance 

    Returns
    -------
    rho: rho is a 36x1 vector of reconstructed reflectance values, all (0->1),

    """
    # todo handle special case of white and black

    # n = cmfs_w.shape[0]  # number of rows
    # z = np.zeros(n)
    z = np.zeros(36)
    lam = np.zeros(3) # lambda
    for _ in range(max_iterations):
        d0 = (np.tanh(z)+1)/2
        sech2 = 1/(np.cosh(z)**2)
        d1 = np.diag(sech2/2)
        d2 = np.diag(-sech2*np.tanh(z))

        f = np.block([d.dot(z)+d1.dot(cmfs_w).dot(lam), np.dot(cmfs_w.T, d0)-XYZ_w])
        j = np.block([[d+np.diag(d2.dot(cmfs_w).dot(lam)), d1.dot(cmfs_w)], [np.dot(cmfs_w.T,d1), np.zeros((3, 3))]])

        delta = linalg.solve(j, -f, assume_a='sym')
        z += delta[0:36]
        lam += delta[36:39]

        if np.all(np.abs(f) < tolerance):
            return (np.tanh(z)+1)/2
