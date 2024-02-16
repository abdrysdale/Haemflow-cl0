subroutine closed_loop_lumped(nstep, &
     T, ncycle, rk, rho, &
     lv_emin, lv_emax, lv_v01, lv_v02, &
     la_emin, la_emax, la_v01, la_v02, &
     rv_emin, rv_emax, rv_v01, rv_v02, &
     ra_emin, ra_emax, ra_v01, ra_v02, &
     pini_sys, scale_Rsys, scale_Csys, &
     sys_ras, sys_rat, sys_rar, sys_rcp, sys_rvn, &
     sys_cas, sys_cat, sys_cvn, sys_las, sys_lat, &
     pini_pulm, scale_Rpulm, scale_Cpulm, &
     pulm_ras, pulm_rat, pulm_rar, pulm_rcp, pulm_rvn, &
     pulm_cas, pulm_cat, pulm_cvn, pulm_las, pulm_lat, &
     av_leff, av_aeffmin, av_aeffmax, av_kvc, av_kvo, &
     mv_leff, mv_aeffmin, mv_aeffmax, mv_kvc, mv_kvo, &
     pv_leff, pv_aeffmin, pv_aeffmax, pv_kvc, pv_kvo, &
     tv_leff, tv_aeffmin, tv_aeffmax, tv_kvc, tv_kvo, &
     t1, t2, t3, t4, &
     q_sk_basal, k_dil, T_cr, T_cr_ref, k_con, T_sk, T_sk_ref, &
     sol_out) bind(c, name='solve_system')
  
  use iso_c_binding
  use funcs
  use data_types
  use kind_parameter

  implicit none

  integer(c_int), intent(in), value :: nstep
  integer(c_int), intent(in), value :: ncycle, rk
  real(c_double), intent(in), value :: T, pini_sys, pini_pulm, rho
  real(c_double), intent(in), value :: scale_Rsys, scale_Csys, scale_Rpulm, scale_Cpulm
  real(c_double), intent(in), value :: t1, t2, t3, t4
  real(c_double), intent(in), value :: lv_emin, lv_emax, lv_v01, lv_v02
  real(c_double), intent(in), value :: la_emin, la_emax, la_v01, la_v02
  real(c_double), intent(in), value :: rv_emin, rv_emax, rv_v01, rv_v02
  real(c_double), intent(in), value :: ra_emin, ra_emax, ra_v01, ra_v02
  real(c_double), intent(in), value :: sys_ras, sys_rat, sys_rar, sys_rcp, sys_rvn
  real(c_double), intent(in), value :: sys_cas, sys_cat, sys_cvn, sys_las, sys_lat
  real(c_double), intent(in), value :: pulm_ras, pulm_rat, pulm_rar, pulm_rcp, pulm_rvn
  real(c_double), intent(in), value :: pulm_cas, pulm_cat, pulm_cvn, pulm_las, pulm_lat
  real(c_double), intent(in), value :: av_leff, av_aeffmin, av_aeffmax, av_kvc, av_kvo
  real(c_double), intent(in), value :: mv_leff, mv_aeffmin, mv_aeffmax, mv_kvc, mv_kvo
  real(c_double), intent(in), value :: pv_leff, pv_aeffmin, pv_aeffmax, pv_kvc, pv_kvo
  real(c_double), intent(in), value :: tv_leff, tv_aeffmin, tv_aeffmax, tv_kvc, tv_kvo
  real(c_double), intent(in), value :: q_sk_basal, k_dil, T_cr, T_cr_ref, k_con, T_sk, T_sk_ref

  type (arterial_system) :: sys, pulm
  type (chamber) :: LV, LA, RV, RA
  type (valve) :: AV, MV, PV, TV
  type (thermal_system) :: therm

  real(c_double) :: scale_Emax, scale_EmaxLV, scale_EmaxRV
  
  real(dp) :: sol(31, nstep)
  real(c_double), intent(out) :: sol_out(31, nstep)

  ! Sets E scales to be 1 - this will likely be removed soon
  ! But will wait for further model development before deciding.
  scale_Emax = real(1, c_double)
  scale_EmaxLV = real(1, c_double)
  scale_EmaxRV = real(1, c_double)

  ! Sets up heart chambers
  LV = chamber(real(lv_emin, dp), real(lv_emax, dp), real(lv_v01, dp), real(lv_v02, dp))
  LA = chamber(real(la_emin, dp), real(la_emax, dp), real(la_v01, dp), real(la_v02, dp))
  RV = chamber(real(rv_emin, dp), real(rv_emax, dp), real(rv_v01, dp), real(rv_v02, dp))
  RA = chamber(real(ra_emin, dp), real(ra_emax, dp), real(ra_v01, dp), real(ra_v02, dp))

  ! Sets up arterial systems
  sys = arterial_system(real(sys_ras, dp), real(sys_rat, dp), real(sys_rar, dp), &
       real(sys_rcp, dp), real(sys_rvn, dp), real(sys_cas, dp), real(sys_cat, dp), &
       real(sys_cvn, dp), real(sys_las, dp), real(sys_lat, dp))
  pulm = arterial_system(real(pulm_ras, dp), real(pulm_rat, dp), real(pulm_rar, dp), &
       real(pulm_rcp, dp), real(pulm_rvn, dp), real(pulm_cas, dp), real(pulm_cat, dp), &
       real(pulm_cvn, dp), real(pulm_las, dp), real(pulm_lat, dp))

  ! Sets up valves
  AV = valve(real(av_leff, dp), real(av_aeffmin, dp), real(av_aeffmax, dp), &
       real(av_kvc, dp), real(av_kvo, dp))
  MV = valve(real(mv_leff, dp), real(mv_aeffmin, dp), real(mv_aeffmax, dp), &
       real(mv_kvc, dp), real(mv_kvo, dp))
  PV = valve(real(pv_leff, dp), real(pv_aeffmin, dp), real(pv_aeffmax, dp), &
       real(pv_kvc, dp), real(pv_kvo, dp))
  TV = valve(real(tv_leff, dp), real(tv_aeffmin, dp), real(tv_aeffmax, dp), &
       real(tv_kvc, dp), real(tv_kvo, dp))

  ! Sets up thermal system
  therm = thermal_system(&
       real(q_sk_basal, dp), &
       real(k_dil, dp), real(T_cr, dp), real(T_cr_ref, dp), &
       real(k_con, dp), real(T_sk, dp), real(T_sk_ref, dp))

  ! Solves the system
  sol = solve_system(int(nstep), &
       real(T, dp), int(ncycle), int(rk), real(pini_sys, dp), real(pini_pulm, dp), &
       AV, MV, PV, TV, &
       real(scale_Rsys, dp), real(scale_Csys, dp), real(scale_Rpulm, dp), real(scale_Cpulm, dp), &
       real(rho, dp), sys, pulm, &
       real(scale_EmaxLV, dp), real(scale_EmaxRV, dp), real(scale_Emax, dp), &
       LV, LA, RV, RA, &
       real(t1, dp), real(t2, dp), real(t3, dp), real(t4, dp), &
       therm)

  sol_out = real(sol, c_double)
end subroutine closed_loop_lumped
