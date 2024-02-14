module thermoregulation
  use kind_parameters

contains

  pure function calc_q_res(M, phi_a, P_a) result (q_res)
    ! Calculates heat loss due to respiration

    ! Declares variables
    real(dp), intent(in) :: M ! Metabolic rate
    real(dp), intent(in) :: phi_a ! Relativity humidity
    real(dp), intent(in) :: P_a ! Saturated vapor pressure of ambient air
    real(dp) :: q_res

    q_res = 0.0023 * M * (44 - phi_a * P_a)
   
  end function calc_q_res

  pure function calc_q_c(h_c, SA, T_sk, T_amb, f_cl) result(q_c)
    ! Calculates the convective heat exchange between skin and external environment

    ! Declare variables
    real(dp), intent(in) :: h_c     ! Convective heat transfer cofficient.
    real(dp), intent(in) :: SA      ! Surface area (m^2).
    real(dp), intent(in) :: T_sk    ! Temperature of skin (C).
    real(dp), intent(in) :: T_a     ! Ambient temperature (C).
    real(dp), intent(in) :: f_cl    ! Heat transfer efficiency of clothing.

    q_c = h_c * SA * (T_sk - T_a) * f_cl

  end function calc_q_c

  pure function calc_q_r(h_r, SA, T_sk, T_a, f_cl) result (q_r)
    ! Calculates the radiative heat exchange between skin and external environment

    ! Declare variables
    real(dp), intent(in) :: h_r     ! Radiative heat transfer cofficient.
    real(dp), intent(in) :: SA      ! Surface area (m^2).
    real(dp), intent(in) :: T_sk    ! Temperature of skin (C).
    real(dp), intent(in) :: T_a     ! Ambient temperature (C).
    real(dp), intent(in) :: f_cl    ! Heat transfer efficiency of clothing.
    
    q_r = h_r * SA * (T_sk - T_a) * f_cl

  end function calc_q_r

  pure function calc_h_c(v) result(h_c)
    ! Calculates convective heat transfer coefficient

    ! Declare variables
    real(dp), intent(in) :: v   ! Wind speed (m/s).
    real(dp) :: h_c             ! Convective heat transfer coefficient.

    h_c = 2.7 + 7.4 * v^0.67
  end function calc_h_c

  pure function calc_fcl(v, clo, h_r, hc) result (f_cl)
    ! Calculates the heat transfer efficiency of clothing

    ! Declares variables
    real(dp), intent(in) :: clo ! Thermal resistance of clothing.
    real(dp), intent(in) :: h_r ! Radiative heat transfer coefficient.
    real(dp), intent(in) :: h_c ! Convective heat transfer.
    real(dp) :: f_cl ! Heat transfer efficiency of clothing.

    f_cl = 1 / (1 + 0.155 * (h_c + h_r) * clo)
  end function calc_fcl

  pure function calc_q_rsw(lambda_h2o, SA, T_sk, T_sk_ref, k_sw, wsig_cr, wsig_sk) result (q_rsw)
    ! Sweating induced heat loss

    ! Declare variables
    real(dp), intent(in) :: lambda_h2o  ! Evaporative heat of water (J/kg).
    real(dp), intent(in) :: SA          ! Body surface area (m^2).
    real(dp), intent(in) :: T_sk        ! Temperature of skin.
    real(dp), intent(in) :: T_sk_ref    ! Temperature of skin at 29.4C and 1 bar.
    real(dp), intent(in) :: k_sw        ! Sweating rate coefficient (g / m^2 / hour / K^2)
    real(dp), intent(in) :: wsig_cr     ! Warm Signal Core
    real(dp), intent(in) :: wsig_sk     ! Warm Signal Skin

    real(dp) :: m_sw                    ! Sweating rate.
    real(dp) :: q_rsw                   ! Sweat induced heating loss

    ! Calculates sweating rate
    m_sw = k_sw * wsig_cr * wsig_sk / 3600000

    q_rsw = lambda_h2o * m_sw * SA * 2^((T_sk - T_sk_ref) / 3)

  end function calc_q_rsw

  pure function calc_q_diff(&
    lambda_h2o, &
    SA, &
    alpha, &
    P_sk, &
    phi_a, &
    P_a, &
    f_pcl, &
    p_rsw, &
    q_rsw, &
    ) result(q_diff)
    ! Skin diffusion induced heat loss

    ! Declare variables
    real(dp), intent(in) :: lambda_h2o  ! Evaporative heat of water (J/kg).
    real(dp), intent(in) :: SA          ! Body surface area (m^2).
    real(dp), intent(in) :: alpha       ! Moisture transfer coefficient (Kg / m^2 / s / mmHg)
    real(dp), intent(in) :: P_sk        ! ?
    real(dp), intent(in) :: phi_a       ! ?
    real(dp), intent(in) :: P_a         ! ?
    real(dp), intent(in) :: f_pcl       ! Vapor transfer efficiency of clothing.
    real(dp), intent(in) :: q_rsw       ! Sweat induced heating loss

    real(dp) :: q_emax  ! Maximum evaporative heat loss
    real(dp) :: p_rsw   ! Skin wetness owing to sweating.
    real(dp) :: p_wet   ! Skin wetness
    real(dp) :: q_diff  ! Skin diffusion heat loss

    ! Maximum evaporative heat loss
    q_emax = lambda_h2o * SA * alpha * (P_sk - phi_a * P_a) * f_pcl

    ! Skin wetness
    p_rsw = q_rsw / q_emax
    p_wet = 0.06 + 0.94 * p_rsw

    q_diff = p_wet * q_emax - q_rsw
  end function calc_q_diff

  pure function calc_q_e(&
       lambda_h2o, &
       SA, &
       T_sk, &
       T_sk_ref, &
       k_sw, &
       wsig_cr, &
       wsig_sk, &
       alpha, &
       P_sk, &
       phi_a, &
       P_a, &
       f_pcl, &
       p_rsw, &
       q_rsw, &
       ) result(q_e)
    ! Heat loss due to diffusion

    ! Declare variables
    real(dp), intent(in) :: lambda_h2o  ! Evaporative heat of water (J/kg).
    real(dp), intent(in) :: SA          ! Body surface area (m^2).
    real(dp), intent(in) :: T_sk        ! Temperature of skin.
    real(dp), intent(in) :: T_sk_ref    ! Temperature of skin at 29.4C and 1 bar.
    real(dp), intent(in) :: k_sw        ! Sweating rate coefficient (g / m^2 / hour / K^2)
    real(dp), intent(in) :: wsig_cr     ! Warm Signal Core
    real(dp), intent(in) :: wsig_sk     ! Warm Signal Skin
    real(dp), intent(in) :: alpha       ! Moisture transfer coefficient (Kg / m^2 / s / mmHg)
    real(dp), intent(in) :: P_sk        ! ?
    real(dp), intent(in) :: phi_a       ! ?
    real(dp), intent(in) :: P_a         ! ?
    real(dp), intent(in) :: f_pcl       ! Vapor transfer efficiency of clothing.

    real(dp) :: q_rsw   ! Heat loss due to sweating
    real(dp) :: q_diff  ! Heat loss due to diffusion
    real(dp) :: q_e     ! Heat loss due to evaporation

    q_rsw = calc_q_rsw((lambda_h2o, SA, T_sk, T_sk_ref, k_sw, wsig_cr, wsig_sk)
    q_diff = calc_q_diff(lambda_h2o, SA, alpha, P_sk, phi_a, P_a, f_pcl, q_rsw)

    q_e = q_rsw + q_diff
    
  end function calc_q_e

  pure function calc_r_cr_sk(eta, c_bl, skbf, M, thickness_fs) result(r_cr_sk)
    ! Calculates the thermal resistance between core and skin.

    ! Declare variables
    real(dp), intent(in) :: eta             ! Countercurrent heat exchange efficiency
    real(dp), intent(in) :: c_bl            ! Specific heat capacity of blood.
    real(dp), intent(in) :: skbf            ! Skin blood flow (l / m^2 / s).
    real(dp), intent(in) :: M               ! Metabolic rate.
    real(dp), intent(in) :: thickness_fs    ! Thickness of fat and skin (mm)

    real(dp) :: r_sk_bf     ! Skin blood flow resistance.
    real(dp) :: r_muscle    ! Resistance of the muscle.
    real(dp) :: r_fs        ! Resistance of the fat and skin.
    real(dp) :: r_mfs       ! Resistance of the muscle, fat and skin.
    real(dp) :: r_cr_sk     ! Resistance between core and skin.

    r_sk_bf = 1 / (eta * c_bl * skbf)
    r_muscle = 0.05 / (1 + (M - 65)/130)
    r_fs = 0.0048 * (thickness_fs - 2) + 0.0044
    r_mfs = r_muscle + r_fs

    r_cr_to_sk = 1 / ((1/r_sk_bf) + (1/r_mfs))

  end function calc_r_cr_sk

  pure function calc_q_cr_sk(SA, T_cr, T_sk, eta, c_bl, skbf, M, thickness_fs) result(q_cr_sk)
    ! Calculates heat exchange between core and skin

    ! Declare variables
    real(dp), intent(in) :: SA              ! Body surface area (m^2).
    real(dp), intent(in) :: T_cr            ! Core temperature (C).
    real(dp), intent(in) :: T_sk            ! Skin temperature (C).
    real(dp), intent(in) :: eta             ! Countercurrent heat exchange efficiency.
    real(dp), intent(in) :: c_bl            ! Specific heat capacity of blood.
    real(dp), intent(in) :: skbf            ! Skin blood flow (l / m^2 / s).
    real(dp), intent(in) :: M               ! Metabolic rate.
    real(dp), intent(in) :: thickness_fs    ! Thickness of fat and skin (mm).

    real(dp) :: r_cr_sk ! Resistance between core and skin.
    real(dp) :: q_cr_sk ! Heat exchange between core and skin.

    r_cr_sk = calc_r_cr_sk(eta, c_bl, skbf, M, thickness_fs)
    q_cr_sk = SA * (T_cr - T_sk) / r_cr_sk

  end function calc_q_cr_sk

  pure function calc_m(m_b, SA, csig_cr, csig_sk) result(m)
    ! Calculates total metabolic rate
    
    ! Declare variables
    real(dp), intent(in) :: m_b     ! Basal metabolic rate.
    real(dp), intent(in) :: SA      ! Surface area (m^2).
    real(dp), intent(in) :: csig_cr ! Cold signal (core).
    real(dp), intent(in) :: csig_sk ! Cold signal (skin).

    real(dp) :: m_shiv  ! Metabolic rate due to shivering.
    real(dp) :: m ! Total metabolic rate.

    m_shiv = 19.4 * SA * csig_cr * csig_sk
    m = m_b * m_shiv
  end function calc_m
