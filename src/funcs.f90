module funcs

    use kind_parameter
    use data_types
    use inputs
    use cust_fns
    use elastance
    use thermoregulation
    implicit none

    private
    public solver
    public solve_system

contains

    ! Solves the system
    pure function solver(sol, a_cof, v_cof, h_cof, elast, therm, k) result(ftot)

        ! Declare input variables
        real(dp), dimension(22), intent(in) :: sol
        type (arterial_network), intent(in) :: a_cof
        type (valve_system), intent(in) :: v_cof
        type (chambers), intent(in) :: h_cof
        type (heart_elastance), intent(in) :: elast
        type (thermal_system), intent(in) :: therm
        integer, intent(in) :: k

        real(dp), dimension(22) :: ftot
        real(dp) :: mmHg, resist, rho
        real(dp) :: Qav, Qsas, Qsat, Qtv, Qpv, Qpas, Qpat, Qmv, Qpvn, Qsvn
        real(dp) :: psas, psat, psvn, ppas, ppat, ppvn
        real(dp) :: Vlv, Vla, Vrv, Vra
        real(dp) :: ksi_av, ksi_mv, ksi_pv, ksi_tv
        real(dp) :: plv, pla, prv, pra
        real(dp), dimension(4) :: Aeff
        real(dp), dimension(4) :: B
        real(dp), dimension(4) :: Z
        real(dp) :: dpav, dpmv, dppv, dptv
        real(dp) :: R_scp

        ! Initialises ftot to be zero
        ftot = 0.0_dp

        mmHg = 1333.0_dp
        resist = 1.0_dp

        ! Flows
        Qav = sol(1)
        Qsas = sol(2)
        Qsat = sol(3)
        Qtv = sol(4)
        Qpv = sol(5)
        Qpas = sol(6)
        Qpat = sol(7)
        Qmv = sol(8)

        ! Pressures
        psas = sol(9)
        psat = sol(10)
        psvn = sol(11)
        ppas = sol(12)
        ppat = sol(13)
        ppvn = sol(14)

        ! Volumes
        Vlv = sol(15)
        Vla = sol(16)
        Vrv = sol(17)
        Vra = sol(18)

        ! Valves
        ksi_av = sol(19)
        ksi_mv = sol(20)
        ksi_pv = sol(21)
        ksi_tv = sol(22)

        ! Blood density
        rho = a_cof%rho

        ! Pressures in the chambers of the heart
        plv = elast%ELV(k) * (Vlv - h_cof%LV%V0_1)
        pla = elast%ELA(k) * (Vla - h_cof%LA%V0_1)
        prv = elast%ERV(k) * (VRv - h_cof%RV%V0_1)
        pra = elast%ERA(k) * (VRa - h_cof%RA%V0_1)

        ! Inductance and resistance systemic 
        ftot(2) = (psas - psat - a_cof%sys%Ras * Qsas) / a_cof%sys%Las

        ! Updates capillary resistance based on thermal model
        R_scp = calc_r_sk(a_cof%sys%Rcp, Qsat, therm)
        ftot(3) = (psat - psvn - (a_cof%sys%Rat + a_cof%sys%Rar + R_scp)* Qsat) / a_cof%sys%Lat
        Qsvn = (psvn  - pra) / a_cof%sys%Rvn

        ! Inductance and resistance pulmonary
        ftot(6) = (ppas - ppat - a_cof%pulm%Ras * Qpas) / a_cof%pulm%Las 
        ftot(7) = (ppat - ppvn - (a_cof%pulm%Rat + a_cof%pulm%Rar + a_cof%pulm%Rcp)* Qpat) / a_cof%pulm%Lat
        Qpvn = (ppvn - pla) / a_cof%pulm%Rvn

        ! Compliance systemic
        ftot(9) = (Qav - Qsas) / a_cof%sys%Cas
        ftot(10) = (Qsas - Qsat) / a_cof%sys%Cat
        ftot(11) = (Qsat - Qsvn) / a_cof%sys%Cvn

        ! Compliance Pulmonary
        ftot(12) = (Qpv - Qpas) / a_cof%pulm%Cas
        ftot(13) = (Qpas - Qpat) / a_cof%pulm%Cat
        ftot(14) = (Qpat - Qpvn) / a_cof%pulm%Cvn

        ! Volume-Flow relations systemic
        ftot(15) = Qmv- Qav
        ftot(16) = Qpvn - Qmv
        ftot(17) = Qtv - Qpv
        ftot(18) = Qsvn - Qtv

        !!! Aortic Valve !!!
        ! Effective area of the valve
        Aeff(1) = (v_cof%AV%Aeffmax - v_cof%AV%Aeffmin) * ksi_av + v_cof%AV%Aeffmin
        ! Bernoulli resistance of the valve
        B(1) = rho / (2 * Aeff(1) ** 2) * resist
        ! Impedance of the valve
        Z(1) = rho * v_cof%AV%Leff/Aeff(1)

        ! Pressure-flow relations through valve
        dpav = (plv - psas) * mmHg
        ftot(1) = (dpav - B(1) * Qav * abs(Qav))/ Z(1)

        if (dpav <= 0) then ! Valve closing
            ftot(19) = ksi_av * v_cof%AV%Kvc * dpav 
        else ! Valve opening
            ftot(19) = (1 - ksi_av) * v_cof%AV%Kvo * dpav
        end if

        !!! Mitral Valve !!!
        Aeff(2) = (v_cof%MV%Aeffmax - v_cof%MV%Aeffmin) * ksi_mv + v_cof%MV%Aeffmin
        B(2) = rho / (2 * Aeff(2) ** 2) * resist
        Z(2) = rho * v_cof%MV%Leff / Aeff(2)

        ! Pressure-flow relations through valve
        dpmv = (pla-plv)*mmHg
        ftot(8) = (dpmv-B(2)*Qmv*abs(Qmv) )/Z(2)

        if (dpmv <= 0)  then ! Valve closing
            ftot(20) = ksi_mv*v_cof%MV%Kvc*dpmv
        else  ! Valve opening
            ftot(20) = (1-ksi_mv)*v_cof%MV%Kvo*dpmv
        end if


        !!! Pulmonary Valve !!!
        Aeff(3) = (v_cof%PV%Aeffmax-v_cof%PV%Aeffmin)*ksi_pv + v_cof%PV%Aeffmin
        B(3) = rho/(2 * Aeff(3) ** 2)*resist
        Z(3) = rho*v_cof%PV%Leff/Aeff(3)

        ! pressure-flow relations through valve
        dppv = (prv-ppas)*mmHg
        ftot(5) = (dppv-B(3)*Qpv*abs(Qpv) )/Z(3)   ! Qpv

        if (dppv <= 0)  then !valve closing
            ftot(21) = ksi_pv*v_cof%PV%Kvc*dppv
        else ! valve opening
            ftot(21) = (1-ksi_pv)*v_cof%PV%Kvo*dppv  ! ksi_pv
        end if

        !!! Tricuspic Valve !!!
        Aeff(4) = (v_cof%TV%Aeffmax-v_cof%TV%Aeffmin)*ksi_tv + v_cof%TV%Aeffmin
        B(4) = rho/(2*Aeff(4)**2)*resist
        Z(4) = rho*v_cof%MV%Leff/Aeff(4)

        ! pressure-flow relations through valve
        dptv = (pra-prv)*mmHg
        ftot(4) = (dptv-B(4)*Qtv*abs(Qtv) )/Z(4)   !Qtv

        if (dptv <= 0)  then ! Valve closing
            ftot(22) = ksi_tv*v_cof%TV%Kvc*dptv
        else ! Valve opening
            ftot(22) = (1-ksi_tv)*v_cof%TV%Kvo*dptv      !ksi_tv
        end if
    end function solver

    function solve_system(&
         nstep, &
         T, &
         ncycle, &
         rk, &
         pini_sys, &
         pini_pulm, &
         AV, &
         MV, &
         PV, &
         TV, &
         scale_Rsys_in, &
         scale_Csys_in, &
         scale_Rpulm_in, &
         scale_Cpulm_in, &
         rho, &
         sys_in, &
         pulm_in, &
         scale_EmaxLV, &
         scale_EmaxRV, &
         scale_Emax, &
         LV_in, &
         LA_in, &
         RV_in, &
         RA_in, &
         t1, &
         t2, &
         t3, &
         t4, &
         therm) result (soln_all)
         
      ! Declares input variables
      integer, intent(in) :: nstep, ncycle, rk
      real(dp), intent(in) :: T, pini_sys, pini_pulm, rho
      real(dp), intent(in) :: scale_Rsys_in, scale_Csys_in, scale_Rpulm_in, scale_Cpulm_in
      real(dp), intent(in) :: scale_Emax, scale_EmaxLV, scale_EmaxRV
      real(dp), intent(in) :: t1, t2, t3, t4
      type (arterial_system), intent(in) :: sys_in, pulm_in
      type (chamber), intent(in) :: LV_in, LA_in, RV_in, RA_in
      type (thermal_system), intent(in) :: therm

      ! Declare temp variables
      integer :: i, icycle, k, offset
      real(dp) :: h, t_val
      real(dp) :: scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm
      type (chamber) :: LV, LA, RV, RA
      type (arterial_system) :: sys, pulm
      type (arterial_network) :: a_cof
      type (chambers) :: h_cof
      type (valve) :: AV, MV, PV, TV
      type (valve_system) :: v_cof
      real(dp), allocatable, dimension(:) :: ELV, ELA, ERV, ERA
      type (heart_elastance) :: elast, elast_half
      real(dp) :: current_sol(22)
      real(dp), allocatable :: h_pres(:, :) 
      real(dp), allocatable :: t_axis(:)
      real(dp), dimension(22) :: k1, k2, k3, k4
      real(dp), allocatable :: sol(:, :)

      ! Declare output variables
      real(dp), allocatable :: soln_all(:, :)


      !!! Initialisation !!!

      ! Relevant arterial coefficients
      sys = sys_in
      pulm = pulm_in
      scale_Rsys = scale_Rsys_in
      scale_Csys = scale_Csys_in
      scale_Rpulm = scale_Rpulm_in
      scale_Cpulm = scale_Cpulm_in
      call artery_input(sys, pulm, scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm)
      a_cof = arterial_network(sys, pulm, rho)

      ! Relevant heart coefficients
      LV = LV_in
      LA = LA_in
      RV = RV_in
      RA = RA_in
      call heart_input(LV, LA, RV, RA, scale_EmaxLV, scale_EmaxRV, scale_Emax)
      h_cof = chambers(LV, LA, RV, RA)

      ! Relevant valve coefficients
      v_cof = valve_system(AV, MV, PV, TV)

      !!! Main code !!!

      ! Calculates elastance curves for the different chambers of the heart
      allocate(t_axis(nstep))
      h = T / real(nstep, dp)
      t_val = 0.0_dp
      do i = 1, nstep
         t_axis(i) = t_val
         t_val = t_val + h
      end do
      allocate(ELV(nstep))
      allocate(ELA(nstep))
      allocate(ERV(nstep))
      allocate(ERA(nstep))
      ! t1 is the time of the P peak
      ! t2 is the time of the R peak
      ! t3 is the time of the T peak
      ! t4 is the time of the end of the T wave (also called T offset)
      ELV = calc_elastance(h_cof%LV, t_axis, t1, t2, t3, t4, is_atria=.false.)
      ELA = calc_elastance(h_cof%LA, t_axis, t1, t2, t3, t4, is_atria=.true.)
      ERV = calc_elastance(h_cof%RV, t_axis, t1, t2, t3, t4, is_atria=.false.)
      ERA = calc_elastance(h_cof%RA, t_axis, t1, t2, t3, t4, is_atria=.true.)

      ! Saves the heart information at the points
      elast = heart_elastance(ELV=ELV, ELA=ELA, ERV=ERV, ERA=ERA)
      elast_half = heart_elastance(ELV=midpoint(ELV), &
           ELA=midpoint(ELA), &
           ERV=midpoint(ERV), &
           ERA=midpoint(ERA))

      ! Initialise the solution
      allocate(sol(22, ncycle * nstep + 1))

      sol(1, 1) = 0.0_dp   ! Flow through aortic valve
      sol(2, 1) = 0.0_dp   ! Flow through sinus
      sol(3, 1) = 0.0_dp   ! Flow through aorta
      sol(4, 1) = 0.0_dp   ! Flow through tricuspid
      sol(5, 1) = 0.0_dp   ! Flow through pulmonary
      sol(6, 1) = 0.0_dp   ! Flow through arteries
      sol(7, 1) = 0.0_dp   ! Flow through arterioles
      sol(8, 1) = 0.0_dp   ! Flow through mitral valve

      sol(9, 1) = pini_sys    ! Initial arterial pressure
      sol(10, 1) = pini_sys    ! Initial arterial pressure
      sol(11, 1) = pini_sys    ! Initial arterial pressure
      sol(12, 1) = pini_pulm    ! Initial pulmonary pressure
      sol(13, 1) = pini_pulm    ! Initial pulmonary pressure
      sol(14, 1) = pini_pulm    ! Initial pulmonary pressure

      sol(15, 1) = h_cof%LV%v0_2    ! End diastolic left ventricular volume
      sol(16, 1) = h_cof%LA%v0_2    ! End diastolic left atrial volume
      sol(17, 1) = h_cof%RV%v0_2    ! End diastolic right ventricular volume
      sol(18, 1) = h_cof%RA%v0_2    ! End diastolic right atrial volume

      sol(19, 1) = 0.0_dp  ! Aortic valve is initially closed.
      sol(20, 1) = 0.0_dp  ! Mitral valve is initially closed.
      sol(21, 1) = 0.0_dp  ! Pulmonary valve is initially closed.
      sol(22, 1) = 0.0_dp  ! Tricuspid valve is initially closed.

      ! Solves the system of equations using a 4th order Runge-Kutta method
      i = 0 ! Initialise

      do icycle = 1, ncycle
         do k = 1, nstep
            i = i + 1
            current_sol = sol(:, i)
            if (rk == 2) then ! Second order Runge-Kutta
               k1 = h * solver(current_sol, a_cof, v_cof, h_cof, elast, therm, k)
               k2 = h * solver(current_sol + k1/2, a_cof, v_cof, h_cof, elast, therm, k)
               sol(:, i+1) = current_sol + k2
            else if (rk == 4) then ! Fourth order Runge-Kutta
               k1 = h * solver(current_sol, a_cof, v_cof, h_cof, elast, therm, k)
               k2 = h * solver(current_sol + k1/2, a_cof, v_cof, h_cof, elast, therm, k)
               k3 = h * solver(current_sol + k2/2, a_cof, v_cof, h_cof, elast, therm, k)
               if ( k /= nstep ) then
                  k4 = h * solver(current_sol + k3, a_cof, v_cof, h_cof, elast, therm, k+1)
               else
                  k4 = h * solver(current_sol + k3, a_cof, v_cof, h_cof, elast, therm, 1)
               end if
               sol(:, i + 1) = current_sol + (k1 + 2 * k2 + 2 * k3 + k4) / 6
            end if
         end do
      end do

      ! Calculates ventricular pressures
      allocate(h_pres(4, nstep))
      offset = (ncycle - 1) * nstep + 2
      h_pres(1, :) = ELV * (sol(15, offset:) - LV%v0_1)
      h_pres(2, :) = ELA * (sol(16, offset:) - LA%v0_1)
      h_pres(3, :) = ERV * (sol(17, offset:) - RV%v0_1)
      h_pres(4, :) = ERA * (sol(18, offset:) - RA%v0_1)

      ! Combines all the parameters
      allocate(soln_all(31, nstep))
      soln_all(1:22, :) = sol(:, offset:)
      soln_all(23:26, :) = h_pres
      soln_all(27, :) = ELV
      soln_all(28, :) = ELA
      soln_all(29, :) = ERV
      soln_all(30, :) = ERA
      soln_all(31, :) = t_axis

    end function solve_system
end module funcs
