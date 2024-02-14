module thermoregulation
  use kind_parameters

contains

  pure function calc_resistance_index(&
    q_sk_basal, &
    k_dil, T_cr, T_cr_ref, &
    k_con, T_sk, T_sk_ref) result(lambda)
    ! Calculates the resistance index for the skin based on Gagge's two node model

    ! Declares variables
    real(dp), intent(in) :: q_sk_basal  ! Basal skin flow at neutral conditions
    real(dp), intent(in) :: k_dil       ! Coefficient of vasodilation
    real(dp), intent(in) :: T_cr        ! Core temperature
    real(dp), intent(in) :: T_cr_ref    ! Core temperature at neutral conditions
    real(dp), intent(in) :: k_con       ! Coefficient of vasoconstriction
    real(dp), intent(in) :: T_sk        ! Skin temperature
    real(dp), intent(in) :: T_sk_ref    ! Skin temperature at neutral condtions

    real(dp) :: wsig_cr                 ! Warm signal - core.
    real(dp) :: csig_sk                 ! Cold signal - skin.
    real(dp) :: lambda                  ! Resistance index.

    wsig_cr = max(0, T_cr - T_cr_ref)
    csig_sk = max(0, T_sk_ref - T_sk)

    lambda = (q_sk_basal + k_dil * wsig_cr) / (q_sk_basal * (1 + k_con * csig_sk))

  end function calc_resistance_index

  subroutine update_skin_resistance(&
    r_sk, &
    q_sk_basal, &
    k_dil, T_cr, T_cr_ref, &
    k_con, T_sk, T_sk_ref)
    ! Updates the skin resistance based on Gagge's two-node thermal model.

    ! Declares variables
    real(dp), intent(in) :: q_sk_basal  ! Basal skin flow at neutral conditions
    real(dp), intent(in) :: k_dil       ! Coefficient of vasodilation
    real(dp), intent(in) :: T_cr        ! Core temperature
    real(dp), intent(in) :: T_cr_ref    ! Core temperature at neutral conditions
    real(dp), intent(in) :: k_con       ! Coefficient of vasoconstriction
    real(dp), intent(in) :: T_sk        ! Skin temperature
    real(dp), intent(in) :: T_sk_ref    ! Skin temperature at neutral condtions

    real(dp), intent(inout) :: r_sk     ! Skin resistance

    real(dp) :: lambda                  ! Resistance index
    lambda = calc_resistance_index(&
         q_sk_basal, &
         k_dil, T_cr, T_cr_ref, &
         k_con, T_sk, T_sk_ref)

    r_sk = r_sk / lambda

  end subroutine update_skin_resistance
