module elastance

    use kind_parameter
    use data_types
    implicit none

    private
    public calc_elastance
    public update_heart_vol

contains

    ! Atria elastance activation functions taken from:
    ! J. D. Thomas, J. Zhou, N. Greenberg, G. Bibawy, P. M. McCarthy, and P. M. Vandervoort, 
    ! “Physical and physiological determinants of pulmonary venous flow: Numerical analysis,” 
    ! Amer. J. Physiol. Heart Circ. Physiol., vol. 272, no. 5, pp. H2453–H2465, 1997.
    elemental function atria_act(t, T1, T2) result(u_a)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T1
      real(dp), intent(in) :: T2
      real(dp) :: u_a
      real(dp), parameter :: pi=4.D0*datan(1.D0)

      if ( (T1 <= t) .and. (t <= T2) ) then
         u_a = 0.5 * (1 - cos((2*pi*(t - T1))/(T2 - T1)))
      else
         u_a = 0
      end if
    end function atria_act

    ! Ventrical elastance activation functions taken from:
    ! D. C. Chung, S. C. Niranjan, J. W. Clark, A. Bidani, W. E. Johnston, J. B. Zwischenberger, and D. L. Traber, 
    ! “A dynamic model of ventricular interaction and pericardial influence,”
    ! Amer. J. Physiol. Heart Circ. Physiol., vol. 272, no. 6, pp. H2942–H2962, Jun. 1, 1997.
    elemental function ventrical_act(t, T2, T3, T4) result(u_v)
      real(dp), intent(in) :: t
      real(dp), intent(in) :: T2
      real(dp), intent(in) :: T3
      real(dp), intent(in) :: T4
      real(dp) :: u_v
      real(dp), parameter :: pi=4.D0*datan(1.D0)

      if ( (T2 <= t) .and. (t < T3) ) then
         u_v = 0.5 * (1 - cos((pi*(t - T2))/(T3 - T2)))
      else if ( (T3 <= t) .and. (t <= T4) ) then
         u_v = 0.5 * (1 + cos((pi*(t - T3))/(T4 - T3)))
      else
         u_v = 0
      end if

    end function ventrical_act

    ! Calculates the elastance of the heart
    elemental function calc_elastance(cham, t, T1, T2, T3, T4, is_atria) result(E_out)

        ! Declares input variables
        type(chamber), intent(in) :: cham
        real(dp), intent(in) :: T1
        real(dp), intent(in) :: T2
        real(dp), intent(in) :: T3
        real(dp), intent(in) :: T4
        real(dp), intent(in) :: t
        logical, intent(in) :: is_atria

        ! Declares output variable
        real(dp) :: E_out

        if (is_atria) then
           E_out = cham%Emin + (cham%Emax - cham%Emin) * atria_act(t, T1, T2)
        else
           E_out = cham%Emin + (cham%Emax - cham%Emin) * ventrical_act(t, T2, T3, T4)
        end if
    end function calc_elastance

    
    ! Heart volume calculations taken from:
    ! "Size matters! Impact of age, sex, height, and weight on the normal heart size"
    ! by Pfaffenberger, Stefan and Bartko, Philipp and Graf, Alexandra and Pernicka, Elisabeth 
    ! and Babayev, Jamil and Lolic, Emina and Bonderman, Diana and Baumgartner, Helmut 
    ! and Maurer, Gerald and Mascherbauer, Julia
    ! Journal: Circulation: Cardiovascular Imaging
    ! Year: 2013
    ! DOI: https://doi.org/10.1161/CIRCIMAGING.113.000690
    subroutine update_heart_vol(heart, height_in, weight_in, age_in, sex_in)
      ! Calculates the heart volume based of height, weight age and sex
      ! The units for each variable are as follows
      ! 
      ! | Variable | Unit  |
      ! |----------|-------|
      ! | Height   | cm    |
      ! | Weight   | kg    |
      ! | Age      | Years |
      ! 
      ! Sex is 0 for a male and 1 for a female.
      ! 
      ! Limitations taken from the study:
      !
      ! > Our data have been collected in a single center in central Europe,
      ! > thus the ethnic background of our study population was mainly
      ! > whites.  No Asian or black individuals were studied. Thus,
      ! > conclusions concerning other ethnic populations are limited.
      ! 
      ! Additionally, the paper did not discuss trans or non-binary people so this is
      ! another limitation of the study.
      ! 
      ! Conculusions taken from the study:
      !
      ! > The present work shows that sex, age, and body size affect the
      ! > normal heart size.  These parameters need to be considered when
      ! > cutoff values indicating the need for treatment or even surgery are
      ! > applied.

      type(chambers), intent(inout) :: heart
      real(dp), intent(in) :: height_in    ! Height (cm)
      real(dp), intent(in) :: weight_in    ! Weight (kg)
      real(dp), intent(in) :: age_in       ! Age (Years)
      real(dp), intent(in) :: sex_in       ! Sex (0 for male, 1 for female)
      real(dp) :: height, weight, age, sex

      ! i = intecept, w = weight, h = height, s = sex
      ! Paper did not have data for right ventricle.
      real(dp) :: lv_i, lv_w, lv_h, lv_a, lv_s    ! Left Ventricle
      real(dp) :: la_i, la_w, la_h, la_a          ! Left Atrium
      real(dp) :: ra_i, ra_w, ra_s                ! Right atrium

      real(dp) :: lv_vol, la_vol, ra_vol
      real(dp) :: lv_scale, la_scale, ra_scale, rv_scale

      !!!!!!!!!!!!!!!!!!!!!
      !!! Checks inputs !!!
      !!!!!!!!!!!!!!!!!!!!!

      if ( (abs(sex_in) <= 1e-5_dp) .and. (abs(sex_in - 1.0_dp) <= 1e-5_dp) ) then
         print *,"Sex is not 0 (male) or 1 (female). Setting to 1."
         sex = 1.0_dp
      else
         sex = sex_in
      end if

      if ( height_in <= 0.0_dp) then
         print *,"Height cannot be less than 0, setting to 160cm"
         height = 160_dp
      else
         height = height_in
      end if

      if ( weight_in <= 0.0_dp) then
         print *,"Weight cannot be less than 0, setting to 80kg"
         weight = 80_dp
      else
         weight = weight_in
      end if

      if ( age_in <= 18 ) then
         print *,"This calculation is not supported for children, setting to 18 years old"
         age = 18_dp
      else
         age = age_in
      end if
        

      lv_i = -39.37731_dp
      lv_w = 0.42808_dp
      lv_h = 0.73703_dp
      lv_s = -9.47838_dp
      lv_a = -0.33895_dp
      la_i = -34.73810_dp
      la_w = 0.21533_dp
      la_h = 0.31554_dp
      la_a = 0.10538_dp
      ra_i = 18.97912_dp
      ra_w = 0.27999_dp
      ra_s = -8.55635_dp

      lv_vol = lv_i + lv_w * weight + lv_h * height + lv_s * sex + lv_a * age
      la_vol = la_i + la_w * weight + la_h * height + la_a * age
      ra_vol = ra_i + ra_w * weight + ra_s * sex

      lv_scale = lv_vol / heart%LV%V0_2
      la_scale = la_vol / heart%LA%V0_2
      ra_scale = ra_vol / heart%RA%V0_2
      rv_scale = (lv_scale + la_scale + ra_scale) / 3

      heart%LV%V0_2 = lv_vol
      heart%LV%V0_1 = heart%LV%V0_1 * lv_scale

      heart%LA%V0_2 = la_vol
      heart%LA%V0_1 = heart%LA%V0_1 * la_scale

      heart%RA%V0_2 = ra_vol
      heart%RA%V0_1 = heart%RA%V0_1 * ra_scale

      heart%RV%V0_2 = heart%RV%V0_2 * rv_scale
      heart%RV%V0_1 = heart%RV%V0_1 * rv_scale

    end subroutine update_heart_vol

end module elastance
