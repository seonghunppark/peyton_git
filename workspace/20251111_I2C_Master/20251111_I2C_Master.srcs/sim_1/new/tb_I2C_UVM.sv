`include "uvm_macros.svh"
import uvm_pkg::*;


interface i2c_intf (
    input logic clk,
    input logic reset
);

    logic       i2c_en;
    logic       i2c_start;
    logic       i2c_stop;
    logic [7:0] tx_data;
    logic       tx_done;
    logic       tx_ready;
    logic [7:0] rx_data;
    logic       rx_done;
    // slave to LED
    logic [7:0] slv_reg1;
    logic [7:0] slv_reg2;
    logic [3:0] led;
    logic [7:0] temp_addr;
    logic [7:0] temp_tx_data;



endinterface  //adder_intf

// Transaction Class : a_seq_item
// 역할 : 하나의 트랜잭션(테스트 데이터)를 담는 객체
// a_seq_item이라는 클래스를 정의하는데 
// uvm_sequence_item에서 상속을 받는다.
class i2c_seq_item extends uvm_sequence_item;
    bit            i2c_en;
    bit            i2c_start;
    bit            i2c_stop;
    bit [7:0] temp_tx_data;
    rand bit      [7:0] tx_data;
    bit [7:0] rx_data;
    rand bit [7:0] slv_reg2;



    // 생성자 함수를 정의하는데 이름은 ITEM이고
    function new(input string name = "ITEM");
        super.new(name);
        // super= 나의 부모 클래스를 가리키는 키워드
        // 나의 부모클래스의 new()함수를 호출해줘.
    endfunction  //new()

    // UVM Factory등록 + print/copy/compare 자동 생성
    `uvm_object_utils_begin(i2c_seq_item)
        `uvm_field_int(i2c_en, UVM_DEC)
        `uvm_field_int(temp_tx_data, UVM_DEC)
        `uvm_field_int(i2c_start, UVM_DEC)
        `uvm_field_int(i2c_stop, UVM_DEC)
        `uvm_field_int(tx_data, UVM_DEC)
        `uvm_field_int(slv_reg2, UVM_DEC)
    `uvm_object_utils_end
endclass  //a_seq_item extends uvm_sequence_item

// Sequence 클래스
// a_sequence라는 이름의 클래스를 정의할 건데 
// uvm_sequence로부터 상속받는다. 
// 여기서 #(a_seq_item)은 Parameterized Class인데
// 전용 열차(a_seq_item 전용), 
// 이 시퀀스는 a_seq_item 타입의 트랜잭션만 다룰 거야.
class i2c_sequence extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_sequence)  // 팩토리에 등록하고

    i2c_seq_item i2c_item;  // 트랜잭션 핸들러를 만들고

    function new(input string name = "SEQ");
        super.new(name);  // 부모클래스의 new함수를 호출하고
    endfunction  //new()

    // 테스트 시나리오 생성기(어떤 데이터를 언제 보낼지 결정)
    // run_phase에서 자동 호출 될거임.
    // seq.start(sequencer)하면 이 task가 실행됨
    task body();
        #10;
        // UVM 팩토리를 사용해서 a_seq_item 객체를 동적으로 생성
        // a_item 핸들은 이제 유효한 transaction 객체를 가리킨다.
        // 여기서 SEQ는 생성된 객체의 instance name이다.
        i2c_item = i2c_seq_item::type_id::create("SEQ");

        // 10개의 테스트 케이스 생성 
        for (int i = 0; i < 15; i++) begin
            start_item(i2c_item);  // sequencer에게 "보낼 준비 됐어" 알림
            // a, b 랜덤 생성 
            if (!i2c_item.randomize()) `uvm_error("SEQ", "Randomize error");
            //나중에 이렇게 제약을 줄 수도 있다. 
            //a_item.randomize() with { a > 100; b < 50; };

            // 로그 출력
            `uvm_info("SEQ", $sformatf(
                      "Data send to Driver tx_data: %0d",i2c_item.tx_data ), UVM_NONE)

            // Sequencer에게 "전송 완료" 혹은 "이제 진짜 보내" 알림                      
            finish_item(i2c_item);  // 이 코드일 때 데이터가 보내짐.
        end
    endtask

endclass  //a_sequence extends uvm_sequence


///////////////// Driver Class /////////////////////
// 이것도 a_seq_item 전용통로 만들고
// 만약에 다른 타입의 item오면 컴파일 타임에 바로 에러
// Factory에 class를 등록해주고
class i2c_driver extends uvm_driver #(i2c_seq_item);
    // uvm_driver는 uvm_component 계열이라서 object가 아니다. 
    `uvm_component_utils(i2c_driver)
    function new(input string name = "DRV", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    i2c_seq_item i2c_item;  // sequencer가 보내준 트랜잭션 받을 그릇
    virtual i2c_intf i2c_if; // DUT 인터페이스 접근하기 위한 가상 인터페이스


    //build_phase는 컴포넌트 생성 -> 연결 설정 단계
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);  // 위에서 아래로 계층 생성

        i2c_item = i2c_seq_item::type_id::create("ITEM");

        // 내가 원하는 건 virtual adder_intf 타입이고
        // config_db에서 get을 할건데
        // 검색범위를 "" 빈 문자열이면 자기 자신부터 위쪽 부모까지 찾아서 올라가고
        // "a_if" : config_db에 저장할 때 썼던 key이름 
        // a_if 결과를 저장할 변수이고
        // get이 실패했으면
        if (!uvm_config_db#(virtual i2c_intf)::get(this, "", "i2c_if", i2c_if)) begin
            `uvm_fatal("DRV", "Unable to access uvm_config_db");
        end
        // config_db: 계층 간 데이터 공유 메커니즘
    endfunction

    // Top module에서 set()으로 저장한 인터페이스를 get()으로 가져온다.
    task run_phase(uvm_phase phase);
        #10;
        forever begin
            seq_item_port.get_next_item(i2c_item);  // Sequencer에서 데이터 받고

            i2c_if.tx_data <= 8'b1010_1000;

            @(posedge i2c_if.clk);  // dut에 신호를 보내주고 
            i2c_if.i2c_en <=1'b1;
            i2c_if.i2c_start <= 1'b1;
            i2c_if.i2c_stop <= 1'b0;
            repeat (1500) @(posedge i2c_if.clk);
              // 한 클럭 기다리고
            // 어떤 데이터 보냈는 지 찍어보고
            `uvm_info("DRV", $sformatf(
                      "DRV send to DUT addr: %0d  start : %0d, stop : %0d", i2c_item.tx_data, i2c_item.i2c_start, i2c_item.i2c_stop), UVM_NONE)
            // 한 클럭 더 대기하고
            @(posedge i2c_if.clk);
            wait (i2c_if.tx_done); // ADDR 보내고 뜸;

            i2c_if.i2c_en <=1'b1;                                   //WRITE DATA
            i2c_if.i2c_start <= 1'b0;               //WRITE DATA
            i2c_if.i2c_stop <= 1'b0;                //WRITE DATA
            i2c_if.tx_data <= i2c_item.tx_data; 
            i2c_if.temp_tx_data <= i2c_item.tx_data;            //WRITE DATA

            @(posedge i2c_if.clk);  // dut에 신호를 보내주고 
            @(posedge i2c_if.clk);  // dut에 신호를 보내주고 
            
            i2c_if.tx_data <= 8'b1010_1001;
            i2c_if.i2c_start <= 1'b1;

            `uvm_info("DRV", $sformatf(
                      "DRV send to DUT addr: %0d, start : %0d stop : %0d ", i2c_item.tx_data, i2c_item.i2c_start, i2c_item.i2c_stop), UVM_NONE)

            wait (i2c_if.tx_done);
            repeat (1500) @(posedge i2c_if.clk);
            i2c_if.i2c_start = 1'b1;
            i2c_if.i2c_stop = 1'b1;

            wait (i2c_if.rx_done);
            i2c_if.i2c_start = 1'b1;
            i2c_if.i2c_stop = 1'b0;

            wait (i2c_if.tx_ready);

            //sequencer에게 완료 알림하고
            seq_item_port.item_done();
        end
    endtask

endclass  //a_driver extends uvm_driver #(a_seq_item)

// Monitor Class

class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)

    // Scoreboard로 보낼 포트
    // a_seq_item 전용 통로이고
    // uvm_analysis_port는 broadcast로 보내주는 역할인데 
    // 지금은 send라는 이름의 포트만 만들었고 
    uvm_analysis_port #(i2c_seq_item) send;

    function new(input string name = "MON", uvm_component c);
        super.new(name, c);
        // 여기서 write하면 연결된 모든 컴포넌트에 broadcast된다.
        // 그럼 어디에 broadcast할 건데?
        send = new("Write", this);
    endfunction  //new()

    i2c_seq_item i2c_item;  //모니터링한 데이터를 담을 transaction 
    virtual i2c_intf i2c_if;  // dut 신호에 직접 접근할 가상 인터페이스


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_item = i2c_seq_item::type_id::create("ITEM");
        if (!uvm_config_db#(virtual i2c_intf)::get(this, "", "i2c_if", i2c_if)) begin
            `uvm_fatal("MON", "Unable to access uvm_config_db");
        end
    endfunction

    task run_phase(uvm_phase phase);
        #10;
        forever begin
            @(posedge i2c_if.clk);
            

            @(negedge i2c_if.rx_done);
           
            i2c_item.tx_data =  i2c_if.temp_tx_data;
            i2c_item.rx_data =  i2c_if.rx_data;

            `uvm_info("MON", $sformatf(
                      "Data send to Scoreboard a: %0d, b: %0d",
                      i2c_item.tx_data,
                      i2c_item.rx_data
                      ), UVM_NONE);
            send.write(i2c_item);
            // scoreboard로 전송 (TLM 통신)
            // 이건 analysis인거고 만약에 blocking이였으면
            // put이었겠지
        end
    endtask
endclass  //a_monitor extends uvm_monitor


// agent class를 만드는데 
// agent에 sequencer, driver, monitor가 있다.
class i2c_agent extends uvm_agent;
    // a_agent를 uvm_agent에서 상속받고 
    // 그걸 factory에 등록하고
    `uvm_component_utils(i2c_agent)

    // 생성자 함수 정의하고
    // 여기서 c는 부모 컴포넌트 핸들이다.
    function new(input string name = "AGENT", uvm_component c);
        // 부모 클래스로부터 생성자 함수를 호출하고
        super.new(name, c);
    endfunction  //new()

    //핸들러를 만들어주고
    i2c_monitor i2c_mon;
    i2c_driver i2c_drv;
    uvm_sequencer #(i2c_seq_item) i2c_sqr;  //sequencer : 중재자(Abiter)  

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_mon = i2c_monitor::type_id::create("MON", this);
        i2c_drv = i2c_driver::type_id::create("DRV", this);
        i2c_sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("SQR", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // sequencer와 Driver사이의 연결
        i2c_drv.seq_item_port.connect(i2c_sqr.seq_item_export);
    endfunction

endclass


class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)

    // TLM이라는 이름의 통신 통로를 뚫어줘야한다.
    // #안에는 클래스 이름이 들어가야한다.
    uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) recv;
    i2c_seq_item i2c_item;


    function new(input string name = "SCB", uvm_component c);
        super.new(name, c);
        recv = new("Read", this);
    endfunction  //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_item = i2c_seq_item::type_id::create("ITEM");
    endfunction

    function void write(input i2c_seq_item item);
        i2c_item = item;
        `uvm_info("SCB", $sformatf(
                  "DATA received from Moniter a: %0d, b: %0d",
                  i2c_item.tx_data,
                  i2c_item.rx_data
                  ), UVM_NONE)
        i2c_item.print(uvm_default_line_printer);
        if (i2c_item.rx_data == i2c_item.tx_data) begin
            `uvm_info("SCB", "Test Passed", UVM_NONE)
        end else begin
            `uvm_error("SCB", "Test Failed!")
        end
    endfunction

endclass  //a_scoreboard extends uvm_scoreboard

class i2c_environment extends uvm_env;
    `uvm_component_utils(i2c_environment)

    function new(input string name = "ENV", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    i2c_agent i2c_agt;
    i2c_scoreboard i2c_scb;

    // 생성은 build에서 하는거지
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_agt = i2c_agent::type_id::create("AGT", this);
        i2c_scb = i2c_scoreboard::type_id::create("SCB", this);
    endfunction

    // scoreboard와 monitor가 연결되어있으니깐
    // agent와 Scoreboard를 연결시켜줘야지
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        i2c_agt.i2c_mon.send.connect(i2c_scb.recv);  // TLM 통신 방식
        // agent의 monitor를 scoreboard에 연결시켜주겠다.
    endfunction




endclass  //a_environment extends uvm_env



class i2c_test extends uvm_test;  // uvm_test라는 class를 상속받은 거다.
    `uvm_component_utils(i2c_test)
    // 이 adder_test class를 factory에 등록하겠다.

    function new(input string name = "ADDER_TEST", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    //test에서 만들어야하는 건 Env랑 Sequence이다.
    // test class가 아래처럼 인스턴스 만들어주는 거고
    i2c_sequence    i2c_seq; // 이게 핸들러고
    i2c_environment i2c_env;

    //virtual을 붙이면 는 자식 class에서 내 method를 대신할 수 있다.
    //virtual을 붙이면 자식 클래스에서 다시 만든다.
    //virtual function void build_phase(uvm_phase phase);
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // factory에서 생성 후 전달
        // 여기서 연결하는거지
        i2c_seq = i2c_sequence::type_id::create("SEQ");
        i2c_env = i2c_environment::type_id::create("ENV", this);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_root::get().print_topology(); // UVM구조가 어떻게 되어있는지를 출력해줌
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);  // uvm_factory는 동작을 멈추지 마!
        i2c_seq.start(i2c_env.i2c_agt.i2c_sqr);
        phase.drop_objection(this);  // 생산 다했어, 멈춰도 돼!
        #10; //generator는 끝났지만 driver나 monitor가 아직 안 끝났을 수도 있어서 보통 지연준다.
    endtask
endclass  //adder_test extends uvm_test


module tb_i2c ();
    logic clk;
    logic reset;
    i2c_intf i2c_if (
        clk,
        reset
    );

    // adder dut (
    //     .clk(i2c_if.clk),
    //     .reset(i2c_if.reset),
    //     .a(i2c_if.a),
    //     .b(i2c_if.b),
    //     .y(i2c_if.y)
    // );

    i2c_top dut(
    .clk(i2c_if.clk),
    .reset(i2c_if.reset),
    .i2c_en(i2c_if.i2c_en),
    .i2c_start(i2c_if.i2c_start),
    .i2c_stop(i2c_if.i2c_stop),
    .tx_data(i2c_if.tx_data),
    .tx_done(i2c_if.tx_done),
    .tx_ready(i2c_if.tx_ready),
    .rx_data(i2c_if.rx_data),
    .rx_done(i2c_if.rx_done),
    .slv_reg1(),
    .slv_reg2(),
    .led(),
    .temp_addr()
    );
    always #5 clk = ~clk;

    initial begin
        $fsdbDumpvars();
        $fsdbDumpfile("wave.fsdb");
        clk   = 0;
        reset = 1;
        #10 reset = 0;
    end

    initial begin
        uvm_config_db#(virtual i2c_intf)::set(null, "*", "i2c_if", i2c_if);
        run_test("i2c_test");  // 시작 class 설정
        #10;
        $finish;
    end

 

endmodule

