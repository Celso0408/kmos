!  This file was generated by kMOS (kMC modelling on steroids)
!  written by Max J. Hoffmann mjhoffmann@gmail.com (C) 2009-2013.
!  The model was written by Felix Engelmann.

!  This file is part of kmos.
!
!  kmos is free software; you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation; either version 2 of the License, or
!  (at your option) any later version.
!
!  kmos is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!
!  You should have received a copy of the GNU General Public License
!  along with kmos; if not, write to the Free Software
!  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301
!  USA
!****h* kmos/proclist
! FUNCTION
!    Implements the kMC process list.
!
!******


module proclist
use kind_values
use base, only: &
    update_accum_rate, &
    update_integ_rate, &
    update_chi, &
    determine_procsite, &
    update_clocks, &
    avail_sites, &
    null_species, &
    increment_procstat, &
    get_nrofsites, &
    get_rate, &
    get_accum_rate

use lattice, only: &
    default, &
    default_s, &
    allocate_system, &
    nr2lattice, &
    lattice2nr, &
    add_proc, &
    can_do, &
    set_rate_const, &
    replace_species, &
    del_proc, &
    reset_site, &
    system_size, &
    spuck, &
    get_species


implicit none



 ! Species constants



integer(kind=iint), parameter, public :: nr_of_species = 3
integer(kind=iint), parameter, public :: A = 0
integer(kind=iint), parameter, public :: B = 1
integer(kind=iint), parameter, public :: empty = 2
integer(kind=iint), public :: default_species = empty


! Process constants

integer(kind=iint), parameter, public :: adsA = 1
integer(kind=iint), parameter, public :: adsB = 2
integer(kind=iint), parameter, public :: desA = 3
integer(kind=iint), parameter, public :: desB = 4
integer(kind=iint), parameter, public :: react = 5
integer(kind=iint), parameter, public :: unreact = 6


integer(kind=iint), parameter, public :: representation_length = 0
integer(kind=iint), public :: seed_size = 12
integer(kind=iint), public :: seed ! random seed
integer(kind=iint), public, dimension(:), allocatable :: seed_arr ! random seed


integer(kind=iint), parameter, public :: nr_of_proc = 6


contains

subroutine do_kmc_steps(n)

!****f* proclist/do_kmc_steps
! FUNCTION
!    Performs ``n`` kMC step.
!    If one has to run many steps without evaluation
!    do_kmc_steps might perform a little better.
!    * first update clock
!    * then configuration sampling step
!    * last execute process
!
! ARGUMENTS
!
!    ``n`` : Number of steps to run
!******
    integer(kind=iint), intent(in) :: n

    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint) :: nr_site, proc_nr, i

    do i = 1, n
    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call update_clocks(ran_time)

    call update_integ_rate
    call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)
    call run_proc_nr(proc_nr, nr_site)
    enddo

end subroutine do_kmc_steps

subroutine do_kmc_step()

!****f* proclist/do_kmc_step
! FUNCTION
!    Performs exactly one kMC step.
!    *  first update clock
!    *  then configuration sampling step
!    *  last execute process
!
! ARGUMENTS
!
!    ``none``
!******
    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint) :: nr_site, proc_nr

    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call update_clocks(ran_time)

    call update_integ_rate
    call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)
    call run_proc_nr(proc_nr, nr_site)
end subroutine do_kmc_step

subroutine do_drc_steps(n, process, perturbation)

!****f* proclist/do_drc_steps
! FUNCTION
!    Performs ``n`` kMC steps. Do nothing 50% of time.
!    sampling degree of rate control
!
!    * first update clock
!    * continue in 50%
!    * then configuration sampling step
!    * last execute process
!
! ARGUMENTS
!
!    ``n`` : Number of steps to run
!******
    integer(kind=iint), intent(in) :: n, process
    real(kind=rdouble), intent(in) :: perturbation

    real(kind=rsingle) :: ran_proc, ran_time, ran_site, ran_idle

    integer(kind=iint) :: nr_site, proc_nr

    real(kind=iint) :: accum_rate
    real(kind=iint), dimension(nr_of_proc) :: G, O
    integer(kind=iint) :: accum_pert

    real(kind=rdouble) :: rate_process
    
    integer(kind=iint) :: i

    call get_rate(process,rate_process)

    !init if first loop nothing happens

    call random_number(ran_proc)
    call random_number(ran_site)
    call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)
    
    call get_accum_rate(0, accum_rate)

    do i = 1, n
        !print *,"in loop:",i
        call random_number(ran_time)
        call random_number(ran_proc)
        call random_number(ran_site)
        
        call update_accum_rate
        call get_accum_rate(0, accum_rate)
        call update_clocks(ran_time,2)

        call update_integ_rate

        call random_number(ran_idle)

        if(ran_idle .LE. 0.5) then !execute step

            call random_number(ran_proc)
            call random_number(ran_site)

            call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)

            call get_accum_rate(0, accum_rate)


            G=2*abs(accum_rate)

            if(proc_nr .EQ. process) then
                O(:)=G(:)*abs(perturbation)/rate_process
            else
                O=0.0
            end if

            !update_chi(executed,proc_nr)

            call run_proc_nr(proc_nr, nr_site)
        else
            
            
            !print *,"pl accum_rate nop=",accum_rate
            
            G=-2*abs(accum_rate)
            call get_nrofsites(process, accum_pert)

            O=G*abs(accum_pert*perturbation)/accum_rate

        end if

        !print *, G, O, ran_idle < 0.5

        call update_chi(G,O)
    end do

end subroutine do_drc_steps


subroutine get_next_kmc_step(proc_nr, nr_site)

!****f* proclist/get_kmc_step
! FUNCTION
!    Determines next step without executing it.
!
! ARGUMENTS
!
!    ``none``
!******
    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint), intent(out) :: nr_site, proc_nr

    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call determine_procsite(ran_proc, ran_time, proc_nr, nr_site)

end subroutine get_next_kmc_step

subroutine get_occupation(occupation)

!****f* proclist/get_occupation
! FUNCTION
!    Evaluate current lattice configuration and returns
!    the normalized occupation as matrix. Different species
!    run along the first axis and different sites run
!    along the second.
!
! ARGUMENTS
!
!    ``none``
!******
    ! nr_of_species = 3, spuck = 1
    real(kind=rdouble), dimension(0:2, 1:1), intent(out) :: occupation

    integer(kind=iint) :: i, j, k, nr, species

    occupation = 0

    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                do nr = 1, spuck
                    ! shift position by 1, so it can be accessed
                    ! more straightforwardly from f2py interface
                    species = get_species((/i,j,k,nr/))
                    if(species.ne.null_species) then
                    occupation(species, nr) = &
                        occupation(species, nr) + 1
                    endif
                end do
            end do
        end do
    end do

    occupation = occupation/real(system_size(1)*system_size(2)*system_size(3))
end subroutine get_occupation

subroutine init(input_system_size, system_name, layer, seed_in, no_banner, in_drc_order)

!****f* proclist/init
! FUNCTION
!     Allocates the system and initializes all sites in the given
!     layer.
!
! ARGUMENTS
!
!    * ``input_system_size`` number of unit cell per axis.
!    * ``system_name`` identifier for reload file.
!    * ``layer`` initial layer.
!    * ``no_banner`` [optional] if True no copyright is issued.
!******
    integer(kind=iint), intent(in) :: layer, seed_in
    integer(kind=iint), dimension(1), intent(in) :: input_system_size

    character(len=400), intent(in) :: system_name

    logical, optional, intent(in) :: no_banner
    integer(kind=iint), optional, intent(in) :: in_drc_order

    if (.not. no_banner) then
        print *, "+------------------------------------------------------------+"
        print *, "|                                                            |"
        print *, "| This kMC Model 'simple_model' was written by               |"
        print *, "|                                                            |"
        print *, "|          Felix Engelmann (felix.engelmann@tum.de)          |"
        print *, "|                                                            |"
        print *, "| and implemented with the help of kmos,                     |"
        print *, "| which is distributed under GNU/GPL Version 3               |"
        print *, "| (C) Max J. Hoffmann mjhoffmann@gmail.com                   |"
        print *, "|                                                            |"
        print *, "| kmos is distributed in the hope that it will be useful     |"
        print *, "| but WIHTOUT ANY WARRANTY; without even the implied         |"
        print *, "| waranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR     |"
        print *, "| PURPOSE. See the GNU General Public License for more       |"
        print *, "| details.                                                   |"
        print *, "|                                                            |"
        print *, "| I appreciate, but do not require, attribution.             |"
        print *, "| An attribution usually includes the program name           |"
        print *, "| author, and URL. For example:                              |"
        print *, "| kmos by Max J. Hoffmann, (http://mhoffman.github.com/kmos) |"
        print *, "|                                                            |"
        print *, "+------------------------------------------------------------+"
        print *, ""
        print *, ""
    endif
    if(present(in_drc_order))then
        call allocate_system(nr_of_proc, input_system_size, system_name, in_drc_order)
    else
        call allocate_system(nr_of_proc, input_system_size, system_name)
    endif
    call initialize_state(layer, seed_in)
end subroutine init

subroutine initialize_state(layer, seed_in)

!****f* proclist/initialize_state
! FUNCTION
!    Initialize all sites and book-keeping array
!    for the given layer.
!
! ARGUMENTS
!
!    * ``layer`` integer representing layer
!******
    integer(kind=iint), intent(in) :: layer, seed_in

    integer(kind=iint) :: i, j, k, nr
    ! initialize random number generator
    allocate(seed_arr(seed_size))
    seed = seed_in
    seed_arr = seed
    call random_seed(seed_size)
    call random_seed(put=seed_arr)
    deallocate(seed_arr)
    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                do nr = 1, spuck
                    call reset_site((/i, j, k, nr/), null_species)
                end do
                select case(layer)
                case (default)
                    call replace_species((/i, j, k, default_s/), null_species, default_species)
                end select
            end do
        end do
    end do

    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                select case(layer)
                case(default)
                    call touchup_default_s((/i, j, k, default_s/))
                end select
            end do
        end do
    end do


end subroutine initialize_state

subroutine run_proc_nr(proc, nr_site)

!****f* proclist/run_proc_nr
! FUNCTION
!    Runs process ``proc`` on site ``nr_site``.
!
! ARGUMENTS
!
!    * ``proc`` integer representing the process number
!    * ``nr_site``  integer representing the site
!******
    integer(kind=iint), intent(in) :: proc
    integer(kind=iint), intent(in) :: nr_site

    integer(kind=iint), dimension(4) :: lsite

    call increment_procstat(proc)

    ! lsite = lattice_site, (vs. scalar site)
    lsite = nr2lattice(nr_site, :)

    select case(proc)
    case(adsA)
        call put_A_default_s(lsite)

    case(adsB)
        call put_B_default_s(lsite)

    case(desA)
        call take_A_default_s(lsite)

    case(desB)
        call take_B_default_s(lsite)

    case(react)
        call take_A_default_s(lsite)
        call put_B_default_s(lsite)

    case(unreact)
        call take_B_default_s(lsite)
        call put_A_default_s(lsite)

    end select

end subroutine run_proc_nr

subroutine put_A_default_s(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, A)

    ! disable affected processes
    if(avail_sites(adsA, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(adsA, site)
    endif

    if(avail_sites(adsB, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(adsB, site)
    endif

    ! enable affected processes
    call add_proc(desA, site)
    call add_proc(react, site)

end subroutine put_A_default_s

subroutine take_A_default_s(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, A, empty)

    ! disable affected processes
    if(avail_sites(desA, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(desA, site)
    endif

    if(avail_sites(react, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(react, site)
    endif

    ! enable affected processes
    call add_proc(adsA, site)
    call add_proc(adsB, site)

end subroutine take_A_default_s

subroutine put_B_default_s(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, B)

    ! disable affected processes
    if(avail_sites(adsA, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(adsA, site)
    endif

    if(avail_sites(adsB, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(adsB, site)
    endif

    ! enable affected processes
    call add_proc(desB, site)
    call add_proc(unreact, site)

end subroutine put_B_default_s

subroutine take_B_default_s(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, B, empty)

    ! disable affected processes
    if(avail_sites(desB, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(desB, site)
    endif

    if(avail_sites(unreact, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(unreact, site)
    endif

    ! enable affected processes
    call add_proc(adsA, site)
    call add_proc(adsB, site)

end subroutine take_B_default_s

subroutine touchup_default_s(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    if (can_do(adsA, site)) then
        call del_proc(adsA, site)
    endif
    if (can_do(adsB, site)) then
        call del_proc(adsB, site)
    endif
    if (can_do(desA, site)) then
        call del_proc(desA, site)
    endif
    if (can_do(desB, site)) then
        call del_proc(desB, site)
    endif
    if (can_do(react, site)) then
        call del_proc(react, site)
    endif
    if (can_do(unreact, site)) then
        call del_proc(unreact, site)
    endif
    select case(get_species(site))
    case(A)
        call add_proc(desA, site)
        call add_proc(react, site)
    case(B)
        call add_proc(desB, site)
        call add_proc(unreact, site)
    case(empty)
        call add_proc(adsA, site)
        call add_proc(adsB, site)
    end select

end subroutine touchup_default_s

end module proclist
