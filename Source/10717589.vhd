library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_w : in std_logic;
        o_z0 : out std_logic_vector(7 downto 0);
        o_z1 : out std_logic_vector(7 downto 0);
        o_z2 : out std_logic_vector(7 downto 0);
        o_z3 : out std_logic_vector(7 downto 0);
        o_done : out std_logic;
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;

architecture project_reti_logiche_arch of project_reti_logiche is
    
    type S is(reset, lst_sig, sav_ind, snd_mem, out_sav, out_rst);
    signal curr_state : S;
    
    signal o_sel : std_logic_vector (1 downto 0);
    signal o_sel_en : std_logic;
    
    signal i_reg_mem : std_logic_vector (15 downto 0);
    signal i_reg_mem_en :std_logic;
    
    signal preo_z0 : std_logic_vector (7 downto 0);
    signal preo_z1 : std_logic_vector (7 downto 0);
    signal preo_z2 : std_logic_vector (7 downto 0);
    signal preo_z3 : std_logic_vector (7 downto 0);
    
    signal out_en : std_logic;
    signal i_soft_rst : std_logic;
    
begin

    fsm_delta : process (i_rst,i_clk)
        begin
        --se i_rst passa 1 lo stato viene portato a reset
        --reset continua a ciclare su se stesso fino a quando i_start non viene messo a 1 a questo passa a lst_sig
        --lst_sig passa dopo un ciclo successivo a sav_ind
        --sav_ind continua a ciclare su se stesso fino a quando i_start non viene messo a 0 a questo passa a lst_sig
        --snd_mem passa dopo un ciclo successivo a out_sav
        --out_sav passa dopo un ciclo successivo a out_rst
        --out_rst passa dopo un ciclo successivo a reset
            
            if i_rst='1' then 
                curr_state <= reset;
            elsif i_clk'event and i_clk='1' then
                case curr_state is
                    when reset=>
                        if i_start='1' then
                            curr_state <= lst_sig; 
                        end if; 
                    when lst_sig=>
                        curr_state <= sav_ind;
                    when sav_ind =>
                        if i_start = '0' then
                            curr_state <= snd_mem;
                        end if;
                    when snd_mem =>
                        curr_state <= out_sav;
                    when out_sav =>
                        curr_state <= out_rst;
                    when out_rst =>
                        curr_state <= reset;
                end case;
            end if;
        end process;

    fsm_lambda : process (curr_state)
        begin
            o_mem_we <= '0'; 
            o_mem_en <= '0';
            i_soft_rst <= '0';        
            i_reg_mem_en <='0';
            o_sel_en <='0';
            out_en <= '0';
                    
        -- reset si predispone per la lettura del primo bit e il salvataggio del bit più significativo 
        --      del selettore dell'uscita e attende il passaggio di start ad alto
        -- lst_sig salva il bit meno significativo del selettore dell'uscita
        -- sav_ind salva in un registro l'indirizzo letto input
        -- snd_mem manda in memoria l'indirizzo letto in memoria
        -- out_sav salva in un registro l'indirizzo che viene dalla memoria e mostra i segnali sui registri di output
        -- out_rst resetta i regitri di output 
            case curr_state is
                when reset=> 
                    i_reg_mem_en <='0';
                    o_sel_en <='1';
                when lst_sig=>
                    o_sel_en <='1';
                when sav_ind => 
                    o_sel_en <='0';   
                    i_reg_mem_en <='1';
                when snd_mem=>
                    i_reg_mem_en <='0';
                    o_mem_en <='1';
                when out_sav =>                       
                    out_en <='1';  
                when out_rst =>                       
                    i_soft_rst <='1'; 
                    out_en<='0';                     
            end case;          
        end process;
    
    
    -- Passa l'indirizzo in w dal registro che ho creato io nella macchina
    -- all'out che va in memoria
    
    mem_save : process(i_reg_mem_en)
    begin
        o_mem_addr <= i_reg_mem;
    end process;
    
    -- Salva nel registro o_sel i segnali di i_w nel caso in cui o_sel_en sia 1
    -- Nel caso i_rst o i_soft_rst vengano messi a 1 resetta il contenuto del registro   
     
    selettore : process (o_sel_en,i_rst,i_clk)
        begin
            if i_rst ='1' then 
                o_sel<="00";
            elsif i_soft_rst='1' then
                o_sel<="00";
            elsif o_sel_en ='1' and i_clk'event and i_clk='1' then
                o_sel(1)<=o_sel(0);
                o_sel(0)<=i_w;     
            end if;
        end process;

    -- Salva nel registro i_reg_mem i segnali di i_w nel caso in cui i_reg_mem_en sia 1
    -- Nel caso i_rst o i_soft_rst vengano messi a 1 resetta il contenuto del registro
    
    reg_ind : process (i_reg_mem_en,i_rst,i_clk)
        begin
            if i_rst ='1' then 
                i_reg_mem <= "0000000000000000";
            elsif i_soft_rst='1' then
                i_reg_mem <= "0000000000000000";
            elsif i_reg_mem_en='1' and i_clk'event and i_clk='1' and i_start='1' then
                i_reg_mem(15 downto 1)<=i_reg_mem(14 downto 0);
                i_reg_mem(0)<=i_w; 
            end if;
        end process;
    -- Salva nel registro definito dal registro o_sel il segnale letto in memoria, quindi
    --      porta l'o_done a 1 e contemporaneamente mostra in output i segnali letti nei 
    --      registri di salvataggio delle uscite
    -- Nel caso i_rst venga messi a 1 resetta il contenuto dei registri sia di output e sia di quelli di salvataggio
    -- Nel caso i_soft_rst venga messi a 1 resetta il contenuto dei registri di output
    z_modifier : process (out_en,i_clk,i_rst)    
        begin
            if i_rst ='1' then 
                preo_z0 <= "00000000"; 
                preo_z1 <= "00000000";
                preo_z2 <= "00000000";
                preo_z3 <= "00000000"; 
                o_z0 <= "00000000";
                o_z1 <= "00000000";
                o_z2 <= "00000000";
                o_z3 <= "00000000";
                o_done <='0';
            elsif i_soft_rst='1' then
                o_z0 <= "00000000";
                o_z1 <= "00000000";
                o_z2 <= "00000000";
                o_z3 <= "00000000";
                o_done <='0';
            elsif out_en='1' and i_clk'event and i_clk='0' then
                if o_sel="00" then
                    preo_z0 <= i_mem_data;
                    o_z0 <= i_mem_data;
                    o_z1 <= preo_z1;
                    o_z2 <= preo_z2;
                    o_z3 <= preo_z3;
                elsif o_sel="01" then
                    preo_z1 <= i_mem_data;
                    o_z0 <= preo_z0;
                    o_z1 <= i_mem_data;
                    o_z2 <= preo_z2;
                    o_z3 <= preo_z3;
                elsif o_sel="10" then
                    preo_z2 <= i_mem_data;
                    o_z0 <= preo_z0;
                    o_z1 <= preo_z1;
                    o_z2 <= i_mem_data;
                    o_z3 <= preo_z3;
                elsif o_sel="11" then
                    preo_z3 <= i_mem_data;
                    o_z0 <= preo_z0;
                    o_z1 <= preo_z1;
                    o_z2 <= preo_z2;
                    o_z3 <= i_mem_data;  
                end if;
                o_done<='1';
             end if;
        end process;
        
end project_reti_logiche_arch;