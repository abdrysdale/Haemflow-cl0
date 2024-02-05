module funcs

    use kind_parameter
    use data_types
    implicit none

    private
    public solver

contains

    ! Solves the system
    pure function solver(sol, a_cof, v_cof, h_cof, elast, k) result(ftot)

        ! Declare input variables
        real(dp), dimension(22), intent(in) :: sol
        type (arterial_network), intent(in) :: a_cof
        type (valve_system), intent(in) :: v_cof
        type (chambers), intent(in) :: h_cof
        type (heart_elastance), intent(in) :: elast
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
        ftot(3) = (psat - psvn - (a_cof%sys%Rat + a_cof%sys%Rar + a_cof%sys%Rcp)* Qsat) / a_cof%sys%Lat
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
end module funcs
