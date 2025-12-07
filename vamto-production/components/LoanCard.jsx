
export default function LoanCard({ loan, onReserve }) {

  return (

    <div className="loan-row" style={{ position: "relative" }}>

      {loan.is_credit && <div className="credit-badge">اعتباری</div>}

      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>

        <div className="bank-icon">

          {loan.bank_logo ? <img src={loan.bank_logo} style={{ width: 44, height: 44, objectFit: "contain" }} /> : "🏦"}

        </div>

      </div>

      <div style={{ flex: 1 }}>

        <div style={{ fontWeight: 800 }}>{loan.title}</div>

      </div>

      <div style={{ width: 160 }}>

        <div className="amount">{loan.amount!=null? Number(loan.amount).toLocaleString()+' تومان':''}</div>

        <div className="kv">{loan.installments} ماهه</div>

      </div>

      <div style={{ width: 120, textAlign: "center" }}>

        <div className="price">{loan.price!=null? Number(loan.price).toLocaleString()+' تومان':''}</div>

      </div>

      <div style={{ width: 100 }}>

        <button className="reserve-btn" onClick={() => onReserve(loan.id)}>رزرو</button>

      </div>

    </div>

  );

}

