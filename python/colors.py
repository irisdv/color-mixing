import numpy as np
from prep_arrays import method_prep
from lhtss_method import lhtss_method

from mixbox import lerp, rgb_to_latent, latent_to_rgb

def calculte_colors(sRGB):
    # Convert all sRGB 8 bit integer values to decimal 0.0-1.0
    # Then call sRGBtoLin function
    red = sRGBtoLin(sRGB[0] / 255.00000)
    green = sRGBtoLin(sRGB[1] / 255.00000)
    blue = sRGBtoLin(sRGB[2] / 255.00000)

    return np.array([[red, green, blue]])


def sRGBtoLin(colorChannel):
    # Takes a decimal sRGB gamma encoded color value between 0.0 and 1.0,
    # Returns a linearized value.
    if colorChannel <= 0.04045:
        return colorChannel / 12.92
    else:
        return pow(((colorChannel + 0.055) / 1.055), 2.4)

def linTosRGB(rgb):
    sRGB = np.zeros(3)
    for i in range(3):
        if rgb[i] < 0.0031308:
            sRGB[i] = 12.92 * rgb[i] * 255
        else:
            sRGB[i] = (1.055 * rgb[i]**(1/2.4) - 0.055) *255
    return sRGB

def getLuminance(vR, vG, vB):
    Y = (0.2126 * sRGBtoLin(vR) + 0.7152 * sRGBtoLin(vG) + 0.0722 * sRGBtoLin(vB))
    return Y

def get_target_xyz(color, D65ToXYZ):
    # convert RGB linear values to XYZ 
    target_xyz = [[0,0,0]]
    for i in range(len(color)):
        for j in range(len(D65ToXYZ[0])):
            for k in range(len(D65ToXYZ)):
                target_xyz[i][j] += color[i][k] * D65ToXYZ[j][k]
    return target_xyz

if __name__ == "__main__":
    # get linear RGB colors to preserves mathematical property of additivity
    c1 = calculte_colors([0,33,133])
    c2 = calculte_colors([252,211,0])

    # http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    D65ToXYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
        [0.2126729, 0.7151522, 0.0721750],
        [0.0193339, 0.1191920, 0.9503041]])

    target_xyz1 = get_target_xyz(c1, D65ToXYZ)
    target_xyz2 = get_target_xyz(c2, D65ToXYZ)

    # The CIE 1931 colour matching function for 380 - 730 nm in 10 nm intervals D65 weighted
    cmfs = np.array([[0.0000646936115727633, 0.00000184433541764457, 0.000305024750978023],
    [0.000219415369171578, 0.0000062054782702308, 0.00103683251144092],
    [0.00112060228414359, 0.0000310103776744139, 0.00531326877604233],
    [0.00376670730427686, 0.000104750996050908, 0.0179548401495523],
    [0.0118808497572766, 0.000353649345357243, 0.057079004340659],
    [0.0232870228938867, 0.000951495123526191, 0.11365445199637],
    [0.0345602796797156, 0.00228232006613489, 0.173363047597462],
    [0.0372247180152918, 0.00420743392201395, 0.196211466514214],
    [0.0324191842208867, 0.00668896510747318, 0.186087009289904],
    [0.0212337349018611, 0.00988864251316196, 0.139953964010199],
    [0.0104912522835777, 0.015249831581587, 0.0891767523322851],
    [0.00329591973705558, 0.0214188448516808, 0.0478974052884572],
    [0.000507047802540891, 0.0334237633103485, 0.0281463269981882],
    [0.000948697853868474, 0.0513112925264347, 0.0161380645679562],
    [0.00627387448845597, 0.0704038388936896, 0.00775929533717298],
    [0.0168650445840847, 0.0878408968669549, 0.00429625546625385],
    [0.0286903641895679, 0.0942514030194481, 0.00200555920471153],
    [0.0426758762490725, 0.0979591120948518, 0.000861492584272158],
    [0.0562561504260008, 0.094154532672617, 0.000369047917008248],
    [0.0694721289967602, 0.0867831869897857, 0.000191433500712763],
    [0.0830552220141023, 0.078858499565938, 0.000149559313956664],
    [0.0861282432155783, 0.0635282861874625, 0.0000923132295986905],
    [0.0904683927868683, 0.0537427564004085, 0.0000681366166724671],
    [0.0850059839999687, 0.0426471274206905, 0.0000288270841412222],
    [0.0709084366392777, 0.0316181374233466, 0.0000157675750930075],
    [0.0506301536932269, 0.0208857265390802, 0.00000394070233244055],
    [0.0354748461653679, 0.0138604556350511, 0.00000158405207257727],
    [0.0214687454102844, 0.00810284218307029, 0],
    [0.0125167687669176, 0.00463021767605804, 0],
    [0.00680475126078526, 0.002491442109212, 0],
    [0.00346465215790157, 0.00125933475912608, 0],
    [0.00149764708248624, 0.000541660024106255, 0],
    [0.000769719667700118, 0.000277959820700288, 0],
    [0.000407378212832335, 0.000147111734433903, 0],
    [0.000169014616182123, 0.0000610342686915558, 0],
    [0.0000952268887534793, 0.0000343881801451621, 0]])

    n = cmfs.shape[0] # equal energy illuminant 
    w = np.ones(n)
    # create preparatory arrays d and cmfs_w
    d, cmfs_w = method_prep(cmfs, w)

    # reflectance reconstruction
    rho1 = lhtss_method(d, cmfs_w, target_xyz1[0])
    rho2 = lhtss_method(d, cmfs_w, target_xyz2[0])

    # todo need to add weights in calcul

    mixed_reflectance = np.zeros(36)
    for i in range(len(rho1)):
        mixed_reflectance[i] = np.sqrt(rho1[i] * rho2[i])

    new_xyz = np.dot(cmfs.T, mixed_reflectance)

    new_lin_rgb = np.dot(D65ToXYZ, new_xyz)

    new_rgb = linTosRGB(new_lin_rgb)
    print('resulting color 1', new_rgb)
